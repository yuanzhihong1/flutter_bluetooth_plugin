#include "flutter_bluetooth_plugin.h"

#ifndef NOMINMAX
#define NOMINMAX
#endif

// This must be included before many other Windows headers.
#include <windows.h>

#include <VersionHelpers.h>
#include <objbase.h>
#include <shellapi.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cctype>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <exception>
#include <iomanip>
#include <memory>
#include <mutex>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace flutter_bluetooth_plugin {
namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Devices::Bluetooth::BluetoothAdapter;
using winrt::Windows::Devices::Bluetooth::BluetoothConnectionStatus;
using winrt::Windows::Devices::Bluetooth::BluetoothLEDevice;
using winrt::Windows::Devices::Bluetooth::Advertisement::
    BluetoothLEAdvertisementDataSection;
using winrt::Windows::Devices::Bluetooth::Advertisement::
    BluetoothLEAdvertisementReceivedEventArgs;
using winrt::Windows::Devices::Bluetooth::Advertisement::
    BluetoothLEAdvertisementWatcher;
using winrt::Windows::Devices::Bluetooth::Advertisement::
    BluetoothLEAdvertisementWatcherStatus;
using winrt::Windows::Devices::Bluetooth::Advertisement::
    BluetoothLEAdvertisementWatcherStoppedEventArgs;
using winrt::Windows::Devices::Bluetooth::Advertisement::
    BluetoothLEScanningMode;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattCharacteristic;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattCharacteristicProperties;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattCharacteristicsResult;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattClientCharacteristicConfigurationDescriptorValue;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattCommunicationStatus;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattDescriptor;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattDescriptorsResult;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattDeviceService;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattDeviceServicesResult;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattReadResult;
using winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::
    GattWriteOption;
using winrt::Windows::Devices::Enumeration::DeviceInformation;
using winrt::Windows::Devices::Radios::Radio;
using winrt::Windows::Devices::Radios::RadioState;
using winrt::Windows::Foundation::IInspectable;
using winrt::Windows::Storage::Streams::DataReader;
using winrt::Windows::Storage::Streams::DataWriter;
using winrt::Windows::Storage::Streams::IBuffer;

constexpr char kBluetoothUnavailableCode[] = "bluetooth_unavailable";
constexpr char kInvalidArgumentsCode[] = "invalid_arguments";
constexpr char kOperationFailedCode[] = "operation_failed";
constexpr char kUnsupportedCode[] = "unsupported";

void Put(EncodableMap& map, const char* key, EncodableValue value) {
  map[EncodableValue(std::string(key))] = std::move(value);
}

EncodableValue NullValue() {
  return EncodableValue();
}

EncodableValue StringValue(const std::string& value) {
  return EncodableValue(value);
}

EncodableValue ByteValue(const std::vector<uint8_t>& bytes) {
  return EncodableValue(bytes);
}

EncodableValue StringListValue(const std::vector<std::string>& values) {
  EncodableList list;
  list.reserve(values.size());
  for (const auto& value : values) {
    list.emplace_back(value);
  }
  return EncodableValue(std::move(list));
}

const EncodableMap* ArgumentsAsMap(
    const flutter::MethodCall<EncodableValue>& method_call) {
  const EncodableValue* arguments = method_call.arguments();
  if (!arguments) {
    return nullptr;
  }
  return std::get_if<EncodableMap>(arguments);
}

const EncodableValue* FindArg(const EncodableMap* args, const char* key) {
  if (!args) {
    return nullptr;
  }
  auto it = args->find(EncodableValue(std::string(key)));
  return it == args->end() ? nullptr : &it->second;
}

std::optional<std::string> GetStringArg(const EncodableMap* args,
                                        const char* key) {
  const EncodableValue* value = FindArg(args, key);
  if (!value || std::holds_alternative<std::monostate>(*value)) {
    return std::nullopt;
  }
  if (const auto* string_value = std::get_if<std::string>(value)) {
    return *string_value;
  }
  return std::nullopt;
}

std::string GetRequiredStringArg(const EncodableMap* args, const char* key) {
  auto value = GetStringArg(args, key);
  if (!value || value->empty()) {
    throw std::invalid_argument(std::string("Missing required argument: ") +
                                key);
  }
  return *value;
}

bool GetBoolArg(const EncodableMap* args, const char* key,
                bool default_value = false) {
  const EncodableValue* value = FindArg(args, key);
  if (!value) {
    return default_value;
  }
  if (const auto* bool_value = std::get_if<bool>(value)) {
    return *bool_value;
  }
  return default_value;
}

std::optional<int64_t> GetIntArg(const EncodableMap* args, const char* key) {
  const EncodableValue* value = FindArg(args, key);
  if (!value || std::holds_alternative<std::monostate>(*value)) {
    return std::nullopt;
  }
  if (const auto* int32_value = std::get_if<int32_t>(value)) {
    return *int32_value;
  }
  if (const auto* int64_value = std::get_if<int64_t>(value)) {
    return *int64_value;
  }
  if (const auto* double_value = std::get_if<double>(value)) {
    return static_cast<int64_t>(*double_value);
  }
  return std::nullopt;
}

std::vector<std::string> GetStringListArg(const EncodableMap* args,
                                          const char* key) {
  const EncodableValue* value = FindArg(args, key);
  if (!value || std::holds_alternative<std::monostate>(*value)) {
    return {};
  }
  const auto* list = std::get_if<EncodableList>(value);
  if (!list) {
    return {};
  }

  std::vector<std::string> result;
  result.reserve(list->size());
  for (const auto& item : *list) {
    if (const auto* string_value = std::get_if<std::string>(&item)) {
      result.push_back(*string_value);
    }
  }
  return result;
}

std::vector<uint8_t> GetByteListArg(const EncodableMap* args, const char* key) {
  const EncodableValue* value = FindArg(args, key);
  if (!value || std::holds_alternative<std::monostate>(*value)) {
    return {};
  }
  if (const auto* bytes = std::get_if<std::vector<uint8_t>>(value)) {
    return *bytes;
  }
  if (const auto* int32_values = std::get_if<std::vector<int32_t>>(value)) {
    std::vector<uint8_t> result;
    result.reserve(int32_values->size());
    for (int32_t item : *int32_values) {
      result.push_back(static_cast<uint8_t>(item));
    }
    return result;
  }
  if (const auto* int64_values = std::get_if<std::vector<int64_t>>(value)) {
    std::vector<uint8_t> result;
    result.reserve(int64_values->size());
    for (int64_t item : *int64_values) {
      result.push_back(static_cast<uint8_t>(item));
    }
    return result;
  }
  if (const auto* list = std::get_if<EncodableList>(value)) {
    std::vector<uint8_t> result;
    result.reserve(list->size());
    for (const auto& item : *list) {
      if (const auto* int32_value = std::get_if<int32_t>(&item)) {
        result.push_back(static_cast<uint8_t>(*int32_value));
      } else if (const auto* int64_value = std::get_if<int64_t>(&item)) {
        result.push_back(static_cast<uint8_t>(*int64_value));
      }
    }
    return result;
  }
  return {};
}

std::string ToLower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](char ch) {
    return static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  });
  return value;
}

std::string HStringToString(const winrt::hstring& value) {
  return winrt::to_string(value);
}

std::string FormatBluetoothAddress(uint64_t address) {
  char buffer[13] = {};
  std::snprintf(buffer, sizeof(buffer), "%012llX",
                static_cast<unsigned long long>(address));
  return std::string(buffer);
}

std::string FormatBluetoothAddressDisplay(uint64_t address) {
  const std::string compact = FormatBluetoothAddress(address);
  std::ostringstream stream;
  for (size_t index = 0; index < compact.size(); index += 2) {
    if (index > 0) {
      stream << ':';
    }
    stream << compact.substr(index, 2);
  }
  return stream.str();
}

std::optional<uint64_t> ParseBluetoothAddress(std::string value) {
  value.erase(std::remove_if(value.begin(), value.end(), [](char ch) {
                return ch == ':' || ch == '-' || std::isspace(
                                             static_cast<unsigned char>(ch));
              }),
              value.end());
  if (value.empty()) {
    return std::nullopt;
  }

  const bool looks_hex = value.size() <= 16 &&
                         std::all_of(value.begin(), value.end(), [](char ch) {
                           return std::isxdigit(
                                      static_cast<unsigned char>(ch)) != 0;
                         });
  try {
    size_t parsed = 0;
    uint64_t result = std::stoull(value, &parsed, looks_hex ? 16 : 10);
    if (parsed == value.size()) {
      return result;
    }
  } catch (...) {
  }
  return std::nullopt;
}

std::optional<winrt::guid> ParseGuid(const std::string& value) {
  std::wstring wide = winrt::to_hstring(value).c_str();
  if (wide.empty()) {
    return std::nullopt;
  }
  if (wide.front() != L'{') {
    wide.insert(wide.begin(), L'{');
    wide.push_back(L'}');
  }

  GUID parsed = {};
  if (FAILED(CLSIDFromString(wide.c_str(), &parsed))) {
    return std::nullopt;
  }

  winrt::guid result = {};
  static_assert(sizeof(result) == sizeof(parsed),
                "winrt::guid must match GUID layout");
  std::memcpy(&result, &parsed, sizeof(result));
  return result;
}

std::string GuidToString(const winrt::guid& guid) {
  GUID value = {};
  static_assert(sizeof(value) == sizeof(guid),
                "GUID must match winrt::guid layout");
  std::memcpy(&value, &guid, sizeof(value));

  wchar_t buffer[39] = {};
  if (StringFromGUID2(value, buffer, 39) == 0) {
    return {};
  }
  std::wstring wide(buffer);
  if (wide.size() >= 2 && wide.front() == L'{' && wide.back() == L'}') {
    wide = wide.substr(1, wide.size() - 2);
  }
  return ToLower(winrt::to_string(wide));
}

std::vector<uint8_t> BufferToBytes(const IBuffer& buffer) {
  if (!buffer) {
    return {};
  }
  DataReader reader = DataReader::FromBuffer(buffer);
  std::vector<uint8_t> bytes(reader.UnconsumedBufferLength());
  if (!bytes.empty()) {
    reader.ReadBytes(
        winrt::array_view<uint8_t>(bytes.data(), bytes.data() + bytes.size()));
  }
  return bytes;
}

IBuffer BytesToBuffer(const std::vector<uint8_t>& bytes) {
  DataWriter writer;
  if (!bytes.empty()) {
    writer.WriteBytes(winrt::array_view<const uint8_t>(
        bytes.data(), bytes.data() + bytes.size()));
  }
  return writer.DetachBuffer();
}

std::string AdapterStateString(RadioState state) {
  switch (state) {
    case RadioState::On:
      return "poweredOn";
    case RadioState::Off:
      return "poweredOff";
    case RadioState::Disabled:
      return "unauthorized";
    default:
      return "unknown";
  }
}

std::string ConnectionStateString(BluetoothConnectionStatus status) {
  return status == BluetoothConnectionStatus::Connected ? "connected"
                                                        : "disconnected";
}

std::string GattStatusMessage(GattCommunicationStatus status) {
  switch (status) {
    case GattCommunicationStatus::Success:
      return "Success";
    case GattCommunicationStatus::Unreachable:
      return "The Bluetooth device is unreachable.";
    case GattCommunicationStatus::ProtocolError:
      return "The GATT operation failed with a protocol error.";
    case GattCommunicationStatus::AccessDenied:
      return "Access to the GATT attribute was denied.";
    default:
      return "The GATT operation failed.";
  }
}

bool HasProperty(GattCharacteristicProperties properties,
                 GattCharacteristicProperties flag) {
  return (static_cast<uint32_t>(properties) & static_cast<uint32_t>(flag)) != 0;
}

std::vector<std::string> CharacteristicPropertiesToStrings(
    GattCharacteristicProperties properties) {
  std::vector<std::string> result;
  if (HasProperty(properties, GattCharacteristicProperties::Broadcast)) {
    result.push_back("broadcast");
  }
  if (HasProperty(properties, GattCharacteristicProperties::Read)) {
    result.push_back("read");
  }
  if (HasProperty(properties, GattCharacteristicProperties::WriteWithoutResponse)) {
    result.push_back("writeWithoutResponse");
  }
  if (HasProperty(properties, GattCharacteristicProperties::Write)) {
    result.push_back("write");
  }
  if (HasProperty(properties, GattCharacteristicProperties::Notify)) {
    result.push_back("notify");
  }
  if (HasProperty(properties, GattCharacteristicProperties::Indicate)) {
    result.push_back("indicate");
  }
  if (HasProperty(properties,
                  GattCharacteristicProperties::AuthenticatedSignedWrites)) {
    result.push_back("authenticatedSignedWrites");
  }
  if (HasProperty(properties, GattCharacteristicProperties::ReliableWrites)) {
    result.push_back("reliableWrite");
  }
  if (HasProperty(properties, GattCharacteristicProperties::WritableAuxiliaries)) {
    result.push_back("writableAuxiliaries");
  }
  return result;
}

EncodableMap RawWindowsMap() {
  EncodableMap raw;
  Put(raw, "platform", StringValue("windows"));
  return raw;
}

EncodableMap DeviceMapFromDevice(const BluetoothLEDevice& device) {
  EncodableMap map;
  if (!device) {
    return map;
  }

  const uint64_t address = device.BluetoothAddress();
  const std::string id = address == 0 ? HStringToString(device.DeviceId())
                                      : FormatBluetoothAddress(address);
  const std::string name = HStringToString(device.Name());

  Put(map, "id", StringValue(id));
  Put(map, "name", name.empty() ? NullValue() : StringValue(name));
  if (address != 0) {
    Put(map, "address", StringValue(FormatBluetoothAddressDisplay(address)));
  }
  Put(map, "type", StringValue("ble"));
  Put(map, "isConnected",
      EncodableValue(device.ConnectionStatus() ==
                     BluetoothConnectionStatus::Connected));
  bool paired = false;
  try {
    paired = device.DeviceInformation().Pairing().IsPaired();
  } catch (...) {
  }
  Put(map, "isBonded", EncodableValue(paired));

  EncodableMap raw = RawWindowsMap();
  Put(raw, "deviceId", StringValue(HStringToString(device.DeviceId())));
  Put(raw, "bluetoothAddress", StringValue(FormatBluetoothAddress(address)));
  Put(map, "raw", EncodableValue(std::move(raw)));
  return map;
}

EncodableMap DeviceMapFromDeviceInformation(const DeviceInformation& info) {
  EncodableMap map;
  const std::string id = HStringToString(info.Id());
  const std::string name = HStringToString(info.Name());
  Put(map, "id", StringValue(id));
  Put(map, "name", name.empty() ? NullValue() : StringValue(name));
  Put(map, "type", StringValue("ble"));
  Put(map, "isConnected", EncodableValue(false));
  Put(map, "isBonded", EncodableValue(info.Pairing().IsPaired()));

  EncodableMap raw = RawWindowsMap();
  Put(raw, "deviceId", StringValue(id));
  Put(map, "raw", EncodableValue(std::move(raw)));
  return map;
}

EncodableMap DescriptorMap(const GattDescriptor& descriptor,
                           const std::string& characteristic_uuid) {
  EncodableMap map;
  Put(map, "uuid", StringValue(GuidToString(descriptor.Uuid())));
  Put(map, "characteristicUuid", StringValue(characteristic_uuid));
  Put(map, "value", ByteValue({}));
  Put(map, "raw", EncodableValue(RawWindowsMap()));
  return map;
}

EncodableMap CharacteristicMap(const GattCharacteristic& characteristic,
                               const std::string& service_uuid) {
  EncodableMap map;
  const std::string characteristic_uuid = GuidToString(characteristic.Uuid());
  Put(map, "uuid", StringValue(characteristic_uuid));
  Put(map, "serviceUuid", StringValue(service_uuid));
  Put(map, "properties",
      StringListValue(
          CharacteristicPropertiesToStrings(characteristic.CharacteristicProperties())));
  Put(map, "permissions", StringListValue({}));
  Put(map, "value", ByteValue({}));

  EncodableList descriptors;
  try {
    GattDescriptorsResult descriptors_result =
        characteristic.GetDescriptorsAsync().get();
    if (descriptors_result.Status() == GattCommunicationStatus::Success) {
      for (const auto& descriptor : descriptors_result.Descriptors()) {
        descriptors.emplace_back(
            DescriptorMap(descriptor, characteristic_uuid));
      }
    }
  } catch (...) {
    // Descriptor discovery can fail for protected attributes; expose the
    // characteristic itself so callers can still address known descriptors.
  }
  Put(map, "descriptors", EncodableValue(std::move(descriptors)));
  Put(map, "raw", EncodableValue(RawWindowsMap()));
  return map;
}

EncodableMap ServiceMap(const GattDeviceService& service) {
  EncodableMap map;
  const std::string service_uuid = GuidToString(service.Uuid());
  Put(map, "uuid", StringValue(service_uuid));
  Put(map, "isPrimary", EncodableValue(true));
  Put(map, "includedServices", StringListValue({}));

  EncodableList characteristics;
  try {
    GattCharacteristicsResult characteristics_result =
        service.GetCharacteristicsAsync().get();
    if (characteristics_result.Status() == GattCommunicationStatus::Success) {
      for (const auto& characteristic : characteristics_result.Characteristics()) {
        characteristics.emplace_back(
            CharacteristicMap(characteristic, service_uuid));
      }
    }
  } catch (...) {
    // Leave characteristics empty if Windows denies enumeration for a service.
  }
  Put(map, "characteristics", EncodableValue(std::move(characteristics)));
  Put(map, "raw", EncodableValue(RawWindowsMap()));
  return map;
}

}  // namespace

class FlutterBluetoothPlugin::Impl
    : public std::enable_shared_from_this<FlutterBluetoothPlugin::Impl> {
 public:
  Impl() {
    // Initialize COM as STA. Windows Bluetooth / WinRT APIs MUST run on STA.
    // Flutter's Windows embedding initializes the platform thread as STA.
    winrt::init_apartment(winrt::apartment_type::single_threaded);
  }

  ~Impl() {
    StopScanInternal();
    CloseDevicesInternal();
    ClearEventSink();
  }

  void OnListen(std::unique_ptr<flutter::EventSink<EncodableValue>> events) {
    {
      std::lock_guard<std::mutex> lock(event_mutex_);
      event_sink_ = std::move(events);
    }

    EncodableMap event;
    Put(event, "type", StringValue("adapterState"));
    Put(event, "state", StringValue(CurrentAdapterStateString()));
    SendEvent(std::move(event));
  }

  void OnCancel() { ClearEventSink(); }

  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const std::string& method = method_call.method_name();
    const EncodableMap* args = ArgumentsAsMap(method_call);

    try {
      if (method == "getPlatformVersion") {
        result->Success(EncodableValue(GetPlatformVersion()));
      } else if (method == "isSupported") {
        result->Success(EncodableValue(IsSupported()));
      } else if (method == "getAdapterState") {
        result->Success(EncodableValue(CurrentAdapterStateString()));
      } else if (method == "getAdapterInfo") {
        result->Success(EncodableValue(AdapterInfoMap()));
      } else if (method == "isScanning") {
        result->Success(EncodableValue(IsScanning()));
      } else if (method == "setAdapterName") {
        result->Success(EncodableValue(false));
      } else if (method == "checkPermissions" || method == "requestPermissions") {
        result->Success(EncodableValue(PermissionMap()));
      } else if (method == "requestEnable") {
        result->Success(EncodableValue(false));
      } else if (method == "openBluetoothSettings") {
        OpenBluetoothSettings();
        result->Success();
      } else if (method == "startScan") {
        StartScan(args, result.get());
      } else if (method == "stopScan") {
        StopScanInternal();
        result->Success();
      } else if (method == "getBondedDevices") {
        result->Success(EncodableValue(GetBondedDevices()));
      } else if (method == "getConnectedDevices") {
        result->Success(EncodableValue(GetConnectedDevices(args)));
      } else if (method == "getDevice") {
        GetDevice(args, result.get());
      } else if (method == "getDevices") {
        result->Success(EncodableValue(GetDevices(args)));
      } else if (method == "connect") {
        Connect(args);
        result->Success();
      } else if (method == "disconnect") {
        Disconnect(args);
        result->Success();
      } else if (method == "getConnectionState") {
        result->Success(EncodableValue(GetConnectionState(args)));
      } else if (method == "discoverServices") {
        result->Success(EncodableValue(DiscoverServices(args)));
      } else if (method == "readCharacteristic") {
        result->Success(ByteValue(ReadCharacteristic(args)));
      } else if (method == "writeCharacteristic") {
        WriteCharacteristic(args);
        result->Success();
      } else if (method == "setCharacteristicNotification") {
        SetCharacteristicNotification(args);
        result->Success();
      } else if (method == "readDescriptor") {
        result->Success(ByteValue(ReadDescriptor(args)));
      } else if (method == "writeDescriptor") {
        WriteDescriptor(args);
        result->Success();
      } else if (method == "readRssi") {
        result->Success(EncodableValue(ReadRssi(args)));
      } else if (method == "requestMtu") {
        result->Success(EncodableValue(RequestMtu(args)));
      } else if (method == "getMaximumWriteLength") {
        result->Success(EncodableValue(0));
      } else if (method == "setPreferredPhy") {
        result->Success();
      } else if (method == "readPhy") {
        result->Success(EncodableValue(ReadPhy(args)));
      } else if (method == "requestConnectionPriority") {
        result->Success(EncodableValue(false));
      } else if (method == "createBond" || method == "removeBond") {
        result->Success(EncodableValue(false));
      } else if (method == "isPeripheralSupported") {
        result->Success(EncodableValue(false));
      } else if (method == "startAdvertising") {
        result->Error(kUnsupportedCode,
                      "BLE advertising/peripheral mode is not implemented on Windows.");
      } else if (method == "stopAdvertising") {
        SendAdvertisingState(false, std::nullopt, "stopped");
        result->Success();
      } else if (method == "setGattServerServices") {
        result->Error(kUnsupportedCode,
                      "Local GATT server APIs are not implemented on Windows.");
      } else if (method == "clearGattServerServices") {
        result->Success();
      } else if (method == "updateLocalCharacteristicValue") {
        result->Error(kUnsupportedCode,
                      "Local GATT server APIs are not implemented on Windows.");
      } else if (method == "notifyGattServerCharacteristic") {
        result->Success(EncodableValue(false));
      } else if (method == "connectClassic" || method == "startClassicServer" ||
                 method == "writeClassic") {
        result->Error(kUnsupportedCode,
                      "Classic Bluetooth RFCOMM is not implemented on Windows.");
      } else if (method == "stopClassicServer" || method == "disconnectClassic") {
        result->Success();
      } else {
        result->NotImplemented();
      }
    } catch (const std::invalid_argument& error) {
      result->Error(kInvalidArgumentsCode, error.what());
    } catch (const winrt::hresult_error& error) {
      result->Error(kOperationFailedCode, winrt::to_string(error.message()));
    } catch (const std::exception& error) {
      result->Error(kOperationFailedCode, error.what());
    }
  }

 private:
  std::string GetPlatformVersion() const {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    } else {
      version_stream << "Unknown";
    }
    return version_stream.str();
  }

  BluetoothAdapter DefaultAdapter() const {
    return BluetoothAdapter::GetDefaultAsync().get();
  }

  Radio AdapterRadio(const BluetoothAdapter& adapter) const {
    if (!adapter) {
      return nullptr;
    }
    try {
      return adapter.GetRadioAsync().get();
    } catch (...) {
      return nullptr;
    }
  }

  bool IsSupported() const {
    BluetoothAdapter adapter = DefaultAdapter();
    return adapter && adapter.IsLowEnergySupported();
  }

  std::string CurrentAdapterStateString() const {
    BluetoothAdapter adapter = DefaultAdapter();
    if (!adapter || !adapter.IsLowEnergySupported()) {
      return "unsupported";
    }
    Radio radio = AdapterRadio(adapter);
    if (!radio) {
      return "unknown";
    }
    return AdapterStateString(radio.State());
  }

  EncodableMap AdapterInfoMap() const {
    BluetoothAdapter adapter = DefaultAdapter();
    const bool supported = adapter && adapter.IsLowEnergySupported();
    EncodableMap map;
    Put(map, "isSupported", EncodableValue(supported));
    Put(map, "state", StringValue(CurrentAdapterStateString()));
    Put(map, "name", NullValue());
    if (adapter && adapter.BluetoothAddress() != 0) {
      Put(map, "address",
          StringValue(FormatBluetoothAddressDisplay(adapter.BluetoothAddress())));
    }
    Put(map, "isBleSupported", EncodableValue(supported));
    Put(map, "isMultipleAdvertisementSupported", EncodableValue(false));
    Put(map, "isOffloadedFilteringSupported", EncodableValue(false));
    Put(map, "isOffloadedScanBatchingSupported", EncodableValue(false));
    Put(map, "isLe2MPhySupported", EncodableValue(false));
    Put(map, "isLeCodedPhySupported", EncodableValue(false));
    Put(map, "isLeExtendedAdvertisingSupported", EncodableValue(false));
    Put(map, "isLePeriodicAdvertisingSupported", EncodableValue(false));
    Put(map, "isDiscovering", EncodableValue(IsScanning()));

    EncodableMap raw = RawWindowsMap();
    if (adapter) {
      Put(raw, "deviceId", StringValue(HStringToString(adapter.DeviceId())));
      Put(raw, "bluetoothAddress",
          StringValue(FormatBluetoothAddress(adapter.BluetoothAddress())));
      Put(raw, "isCentralRoleSupported",
          EncodableValue(adapter.IsCentralRoleSupported()));
      Put(raw, "isPeripheralRoleSupported",
          EncodableValue(adapter.IsPeripheralRoleSupported()));
    }
    Put(map, "raw", EncodableValue(std::move(raw)));
    return map;
  }

  bool IsScanning() const {
    return watcher_ && watcher_.Status() == BluetoothLEAdvertisementWatcherStatus::Started;
  }

  EncodableMap PermissionMap() const {
    EncodableMap map;
    Put(map, "bluetooth", StringValue(IsSupported() ? "granted" : "notApplicable"));
    return map;
  }

  void OpenBluetoothSettings() const {
    ShellExecuteW(nullptr, L"open", L"ms-settings:bluetooth", nullptr, nullptr,
                  SW_SHOWNORMAL);
  }

  void StartScan(const EncodableMap* args,
                 flutter::MethodResult<EncodableValue>* result) {
    const std::string scan_mode = GetStringArg(args, "scanMode").value_or("ble");
    if (scan_mode == "classic") {
      result->Error(kUnsupportedCode,
                    "Windows implementation currently supports BLE scanning only.");
      return;
    }
    if (CurrentAdapterStateString() != "poweredOn") {
      result->Error(kBluetoothUnavailableCode,
                    "Bluetooth is not powered on or unavailable.");
      return;
    }

    StopScanInternal();
    allow_duplicates_ = GetBoolArg(args, "allowDuplicates", false);
    {
      std::lock_guard<std::mutex> lock(scan_mutex_);
      seen_scan_devices_.clear();
    }

    BluetoothLEAdvertisementWatcher watcher;
    watcher.ScanningMode(BluetoothLEScanningMode::Active);
    for (const auto& uuid_string : GetStringListArg(args, "serviceUuids")) {
      if (auto uuid = ParseGuid(uuid_string)) {
        watcher.AdvertisementFilter().Advertisement().ServiceUuids().Append(*uuid);
      }
    }

    received_token_ = watcher.Received(
        [weak_self = weak_from_this()](const BluetoothLEAdvertisementWatcher&,
                                       const BluetoothLEAdvertisementReceivedEventArgs& args) {
          if (auto self = weak_self.lock()) {
            self->OnAdvertisementReceived(args);
          }
        });
    stopped_token_ = watcher.Stopped(
        [weak_self = weak_from_this()](const BluetoothLEAdvertisementWatcher&,
                                       const BluetoothLEAdvertisementWatcherStoppedEventArgs&) {
          if (auto self = weak_self.lock()) {
            self->SendAdapterStateEvent();
          }
        });

    watcher_ = watcher;
    watcher_.Start();
    const int generation = ++scan_generation_;

    if (auto timeout_ms = GetIntArg(args, "timeoutMs"); timeout_ms && *timeout_ms > 0) {
      std::weak_ptr<Impl> weak_self = weak_from_this();
      std::thread([weak_self, generation, timeout = *timeout_ms]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(timeout));
        if (auto self = weak_self.lock()) {
          self->StopScanIfGeneration(generation);
        }
      }).detach();
    }

    result->Success();
  }

  void StopScanIfGeneration(int generation) {
    if (scan_generation_.load() != generation) {
      return;
    }
    StopScanInternal();
  }

  void StopScanInternal() {
    ++scan_generation_;
    if (watcher_) {
      try {
        if (watcher_.Status() == BluetoothLEAdvertisementWatcherStatus::Started) {
          watcher_.Stop();
        }
        if (received_token_.value != 0) {
          watcher_.Received(received_token_);
          received_token_ = {};
        }
        if (stopped_token_.value != 0) {
          watcher_.Stopped(stopped_token_);
          stopped_token_ = {};
        }
      } catch (...) {
      }
      watcher_ = nullptr;
    }
  }

  void OnAdvertisementReceived(
      const BluetoothLEAdvertisementReceivedEventArgs& args) {
    const uint64_t address = args.BluetoothAddress();
    const std::string device_id = FormatBluetoothAddress(address);
    {
      std::lock_guard<std::mutex> lock(scan_mutex_);
      if (!allow_duplicates_ && seen_scan_devices_.count(device_id) > 0) {
        return;
      }
      seen_scan_devices_.insert(device_id);
      last_rssi_[device_id] = args.RawSignalStrengthInDBm();
    }

    BluetoothLEDevice device = nullptr;
    try {
      device = BluetoothLEDevice::FromBluetoothAddressAsync(address).get();
      if (device) {
        RememberDevice(device);
      }
    } catch (...) {
    }

    EncodableMap scan_result;
    if (device) {
      Put(scan_result, "device", EncodableValue(DeviceMapFromDevice(device)));
    } else {
      EncodableMap device_map;
      const std::string local_name = HStringToString(args.Advertisement().LocalName());
      Put(device_map, "id", StringValue(device_id));
      Put(device_map, "name", local_name.empty() ? NullValue() : StringValue(local_name));
      Put(device_map, "address", StringValue(FormatBluetoothAddressDisplay(address)));
      Put(device_map, "type", StringValue("ble"));
      Put(device_map, "isConnected", EncodableValue(false));
      Put(device_map, "isBonded", EncodableValue(false));
      Put(device_map, "raw", EncodableValue(RawWindowsMap()));
      Put(scan_result, "device", EncodableValue(std::move(device_map)));
    }

    Put(scan_result, "rssi",
        EncodableValue(static_cast<int32_t>(args.RawSignalStrengthInDBm())));
    const std::string local_name = HStringToString(args.Advertisement().LocalName());
    Put(scan_result, "localName", local_name.empty() ? NullValue() : StringValue(local_name));

    std::vector<std::string> service_uuids;
    for (const auto& uuid : args.Advertisement().ServiceUuids()) {
      service_uuids.push_back(GuidToString(uuid));
    }
    Put(scan_result, "serviceUuids", StringListValue(service_uuids));

    EncodableMap manufacturer_data;
    for (const auto& item : args.Advertisement().ManufacturerData()) {
      manufacturer_data[EncodableValue(std::to_string(item.CompanyId()))] =
          ByteValue(BufferToBytes(item.Data()));
    }
    Put(scan_result, "manufacturerData", EncodableValue(std::move(manufacturer_data)));
    Put(scan_result, "serviceData", EncodableValue(ExtractServiceData(args)));
    Put(scan_result, "raw", EncodableValue(RawWindowsMap()));

    Put(scan_result, "type", StringValue("scanResult"));
    SendEvent(std::move(scan_result));
  }

  EncodableMap ExtractServiceData(
      const BluetoothLEAdvertisementReceivedEventArgs& args) const {
    EncodableMap service_data;
    for (const BluetoothLEAdvertisementDataSection& section :
         args.Advertisement().DataSections()) {
      const uint8_t data_type = section.DataType();
      if (data_type != 0x16 && data_type != 0x20 && data_type != 0x21) {
        continue;
      }
      std::vector<uint8_t> bytes = BufferToBytes(section.Data());
      if (bytes.empty()) {
        continue;
      }
      std::string key;
      size_t uuid_length = 0;
      if (data_type == 0x16 && bytes.size() >= 2) {
        std::ostringstream stream;
        stream << std::hex << std::setfill('0') << std::setw(4)
               << (static_cast<int>(bytes[1]) << 8 | static_cast<int>(bytes[0]));
        key = stream.str();
        uuid_length = 2;
      } else if (data_type == 0x20 && bytes.size() >= 4) {
        std::ostringstream stream;
        for (int index = 3; index >= 0; --index) {
          stream << std::hex << std::setfill('0') << std::setw(2)
                 << static_cast<int>(bytes[index]);
        }
        key = stream.str();
        uuid_length = 4;
      } else if (data_type == 0x21 && bytes.size() >= 16) {
        GUID guid = {};
        std::memcpy(&guid, bytes.data(), 16);
        winrt::guid winrt_guid = {};
        std::memcpy(&winrt_guid, &guid, sizeof(winrt_guid));
        key = GuidToString(winrt_guid);
        uuid_length = 16;
      }
      if (!key.empty()) {
        std::vector<uint8_t> value(bytes.begin() + uuid_length, bytes.end());
        service_data[EncodableValue(key)] = ByteValue(value);
      }
    }
    return service_data;
  }

  EncodableList GetBondedDevices() {
    EncodableList devices;
    try {
      auto selector = BluetoothLEDevice::GetDeviceSelectorFromPairingState(true);
      auto infos = DeviceInformation::FindAllAsync(selector).get();
      for (const auto& info : infos) {
        try {
          BluetoothLEDevice device = BluetoothLEDevice::FromIdAsync(info.Id()).get();
          if (device) {
            RememberDevice(device);
            devices.emplace_back(DeviceMapFromDevice(device));
          } else {
            devices.emplace_back(DeviceMapFromDeviceInformation(info));
          }
        } catch (...) {
          devices.emplace_back(DeviceMapFromDeviceInformation(info));
        }
      }
    } catch (...) {
      // Pairing enumeration can be unavailable on older Windows configurations.
    }
    return devices;
  }

  EncodableList GetConnectedDevices(const EncodableMap* args) {
    EncodableList devices;
    const std::vector<std::string> service_uuids =
        GetStringListArg(args, "serviceUuids");

    std::lock_guard<std::mutex> lock(device_mutex_);
    for (const auto& entry : devices_) {
      const BluetoothLEDevice& device = entry.second;
      if (!device || device.ConnectionStatus() != BluetoothConnectionStatus::Connected) {
        continue;
      }
      if (!service_uuids.empty() && !HasAnyService(device, service_uuids)) {
        continue;
      }
      devices.emplace_back(DeviceMapFromDevice(device));
    }
    return devices;
  }

  void GetDevice(const EncodableMap* args,
                 flutter::MethodResult<EncodableValue>* result) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    BluetoothLEDevice device = ResolveDevice(device_id, true);
    if (!device) {
      result->Success(EncodableValue(EncodableMap{}));
      return;
    }
    result->Success(EncodableValue(DeviceMapFromDevice(device)));
  }

  EncodableList GetDevices(const EncodableMap* args) {
    EncodableList devices;
    const EncodableValue* device_ids_value = FindArg(args, "deviceIds");
    const auto* device_ids = device_ids_value
                                 ? std::get_if<EncodableList>(device_ids_value)
                                 : nullptr;
    if (!device_ids) {
      return devices;
    }

    for (const auto& item : *device_ids) {
      const auto* id = std::get_if<std::string>(&item);
      if (!id) {
        continue;
      }
      BluetoothLEDevice device = ResolveDevice(*id, true);
      if (device) {
        devices.emplace_back(DeviceMapFromDevice(device));
      }
    }
    return devices;
  }

  void Connect(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    BluetoothLEDevice device = ResolveDevice(device_id, true);
    if (!device) {
      throw std::runtime_error("Device not found: " + device_id);
    }

    SendConnectionStateEvent(DeviceKey(device), "connecting", std::nullopt);
    GattDeviceServicesResult services_result =
        device.GetGattServicesAsync().get();
    if (services_result.Status() != GattCommunicationStatus::Success) {
      SendConnectionStateEvent(DeviceKey(device), "disconnected", std::nullopt);
      throw std::runtime_error(GattStatusMessage(services_result.Status()));
    }

    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      std::vector<GattDeviceService> cached_services;
      for (const auto& service : services_result.Services()) {
        cached_services.push_back(service);
      }
      service_cache_.insert_or_assign(DeviceKey(device), std::move(cached_services));
    }
    SendConnectionStateEvent(DeviceKey(device),
                             ConnectionStateString(device.ConnectionStatus()),
                             std::nullopt);
  }

  void Disconnect(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    BluetoothLEDevice device = ResolveDevice(device_id, false);
    if (!device) {
      SendConnectionStateEvent(device_id, "disconnected", std::nullopt);
      return;
    }

    const std::string key = DeviceKey(device);
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      for (auto it = subscriptions_.begin(); it != subscriptions_.end();) {
        if (it->first.rfind(key + "|", 0) == 0) {
          try {
            it->second.characteristic.ValueChanged(it->second.token);
          } catch (...) {
          }
          it = subscriptions_.erase(it);
        } else {
          ++it;
        }
      }
      service_cache_.erase(key);
      characteristic_cache_.clear();
      descriptor_cache_.clear();
      auto token = connection_tokens_.find(key);
      if (token != connection_tokens_.end()) {
        try {
          device.ConnectionStatusChanged(token->second);
        } catch (...) {
        }
        connection_tokens_.erase(token);
      }
      devices_.erase(key);
      last_rssi_.erase(key);
    }
    SendConnectionStateEvent(key, "disconnected", std::nullopt);
  }

  std::string GetConnectionState(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    BluetoothLEDevice device = ResolveDevice(device_id, false);
    if (!device) {
      return "disconnected";
    }
    return ConnectionStateString(device.ConnectionStatus());
  }

  EncodableList DiscoverServices(const EncodableMap* args) {
    BluetoothLEDevice device = ResolveRequiredDevice(args);
    const std::string key = DeviceKey(device);
    GattDeviceServicesResult services_result =
        device.GetGattServicesAsync().get();
    if (services_result.Status() != GattCommunicationStatus::Success) {
      throw std::runtime_error(GattStatusMessage(services_result.Status()));
    }

    EncodableList services;
    std::vector<GattDeviceService> cache;
    for (const auto& service : services_result.Services()) {
      cache.push_back(service);
      services.emplace_back(ServiceMap(service));
    }
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      service_cache_.insert_or_assign(key, std::move(cache));
    }
    return services;
  }

  std::vector<uint8_t> ReadCharacteristic(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    const std::string service_uuid = GetRequiredStringArg(args, "serviceUuid");
    const std::string characteristic_uuid =
        GetRequiredStringArg(args, "characteristicUuid");
    GattCharacteristic characteristic =
        ResolveCharacteristic(device_id, service_uuid, characteristic_uuid);

    GattReadResult read_result = characteristic.ReadValueAsync().get();
    if (read_result.Status() != GattCommunicationStatus::Success) {
      throw std::runtime_error(GattStatusMessage(read_result.Status()));
    }
    std::vector<uint8_t> bytes = BufferToBytes(read_result.Value());
    SendCharacteristicValueEvent(device_id, service_uuid, characteristic_uuid,
                                 bytes);
    return bytes;
  }

  void WriteCharacteristic(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    const std::string service_uuid = GetRequiredStringArg(args, "serviceUuid");
    const std::string characteristic_uuid =
        GetRequiredStringArg(args, "characteristicUuid");
    const std::vector<uint8_t> value = GetByteListArg(args, "value");
    const std::string write_type =
        GetStringArg(args, "writeType").value_or("withResponse");
    GattCharacteristic characteristic =
        ResolveCharacteristic(device_id, service_uuid, characteristic_uuid);

    const GattWriteOption option = write_type == "withoutResponse"
                                      ? GattWriteOption::WriteWithoutResponse
                                      : GattWriteOption::WriteWithResponse;
    GattCommunicationStatus status =
        characteristic.WriteValueAsync(BytesToBuffer(value), option).get();
    if (status != GattCommunicationStatus::Success) {
      throw std::runtime_error(GattStatusMessage(status));
    }
  }

  void SetCharacteristicNotification(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    const std::string service_uuid = GetRequiredStringArg(args, "serviceUuid");
    const std::string characteristic_uuid =
        GetRequiredStringArg(args, "characteristicUuid");
    const bool enable = GetBoolArg(args, "enable", false);
    GattCharacteristic characteristic =
        ResolveCharacteristic(device_id, service_uuid, characteristic_uuid);
    const std::string key = CharacteristicKey(device_id, service_uuid,
                                              characteristic_uuid);

    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      auto existing = subscriptions_.find(key);
      if (existing != subscriptions_.end()) {
        try {
          existing->second.characteristic.ValueChanged(existing->second.token);
        } catch (...) {
        }
        subscriptions_.erase(existing);
      }
    }

    if (!enable) {
      characteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
          GattClientCharacteristicConfigurationDescriptorValue::None).get();
      return;
    }

    const auto properties = characteristic.CharacteristicProperties();
    GattClientCharacteristicConfigurationDescriptorValue descriptor_value =
        HasProperty(properties, GattCharacteristicProperties::Notify)
            ? GattClientCharacteristicConfigurationDescriptorValue::Notify
            : GattClientCharacteristicConfigurationDescriptorValue::Indicate;

    auto token = characteristic.ValueChanged(
        [weak_self = weak_from_this(), device_id, service_uuid,
         characteristic_uuid](const GattCharacteristic&,
                              const winrt::Windows::Devices::Bluetooth::
                                  GenericAttributeProfile::
                                      GattValueChangedEventArgs& event_args) {
          if (auto self = weak_self.lock()) {
            self->SendCharacteristicValueEvent(
                device_id, service_uuid, characteristic_uuid,
                BufferToBytes(event_args.CharacteristicValue()));
          }
        });

    GattCommunicationStatus status =
        characteristic.WriteClientCharacteristicConfigurationDescriptorAsync(
            descriptor_value)
            .get();
    if (status != GattCommunicationStatus::Success) {
      characteristic.ValueChanged(token);
      throw std::runtime_error(GattStatusMessage(status));
    }

    std::lock_guard<std::mutex> lock(device_mutex_);
    subscriptions_.insert_or_assign(key, CharacteristicSubscription{characteristic, token});
  }

  std::vector<uint8_t> ReadDescriptor(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    const std::string service_uuid = GetRequiredStringArg(args, "serviceUuid");
    const std::string characteristic_uuid =
        GetRequiredStringArg(args, "characteristicUuid");
    const std::string descriptor_uuid = GetRequiredStringArg(args, "descriptorUuid");
    GattDescriptor descriptor =
        ResolveDescriptor(device_id, service_uuid, characteristic_uuid,
                          descriptor_uuid);

    GattReadResult read_result = descriptor.ReadValueAsync().get();
    if (read_result.Status() != GattCommunicationStatus::Success) {
      throw std::runtime_error(GattStatusMessage(read_result.Status()));
    }
    std::vector<uint8_t> bytes = BufferToBytes(read_result.Value());
    SendDescriptorValueEvent(device_id, service_uuid, characteristic_uuid,
                             descriptor_uuid, bytes);
    return bytes;
  }

  void WriteDescriptor(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    const std::string service_uuid = GetRequiredStringArg(args, "serviceUuid");
    const std::string characteristic_uuid =
        GetRequiredStringArg(args, "characteristicUuid");
    const std::string descriptor_uuid = GetRequiredStringArg(args, "descriptorUuid");
    const std::vector<uint8_t> value = GetByteListArg(args, "value");
    GattDescriptor descriptor =
        ResolveDescriptor(device_id, service_uuid, characteristic_uuid,
                          descriptor_uuid);

    GattCommunicationStatus status = descriptor.WriteValueAsync(BytesToBuffer(value)).get();
    if (status != GattCommunicationStatus::Success) {
      throw std::runtime_error(GattStatusMessage(status));
    }
    SendDescriptorValueEvent(device_id, service_uuid, characteristic_uuid,
                             descriptor_uuid, value);
  }

  int32_t ReadRssi(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    int32_t rssi = 0;
    {
      std::lock_guard<std::mutex> lock(scan_mutex_);
      auto it = last_rssi_.find(device_id);
      if (it == last_rssi_.end()) {
        if (auto address = ParseBluetoothAddress(device_id)) {
          it = last_rssi_.find(FormatBluetoothAddress(*address));
        }
      }
      if (it != last_rssi_.end()) {
        rssi = it->second;
      }
    }
    EncodableMap event;
    Put(event, "type", StringValue("rssi"));
    Put(event, "deviceId", StringValue(device_id));
    Put(event, "rssi", EncodableValue(rssi));
    SendEvent(std::move(event));
    return rssi;
  }

  int32_t RequestMtu(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    EncodableMap event;
    Put(event, "type", StringValue("mtu"));
    Put(event, "deviceId", StringValue(device_id));
    Put(event, "mtu", EncodableValue(0));
    SendEvent(std::move(event));
    return 0;
  }

  EncodableMap ReadPhy(const EncodableMap* args) {
    EncodableMap map;
    Put(map, "deviceId", StringValue(GetStringArg(args, "deviceId").value_or("")));
    Put(map, "txPhy", StringValue("unknown"));
    Put(map, "rxPhy", StringValue("unknown"));
    return map;
  }

  BluetoothLEDevice ResolveRequiredDevice(const EncodableMap* args) {
    const std::string device_id = GetRequiredStringArg(args, "deviceId");
    BluetoothLEDevice device = ResolveDevice(device_id, true);
    if (!device) {
      throw std::runtime_error("Device not found: " + device_id);
    }
    return device;
  }

  BluetoothLEDevice ResolveDevice(const std::string& device_id,
                                  bool create) {
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      auto it = devices_.find(device_id);
      if (it != devices_.end()) {
        return it->second;
      }
      auto alias = device_aliases_.find(device_id);
      if (alias != device_aliases_.end()) {
        auto device_it = devices_.find(alias->second);
        if (device_it != devices_.end()) {
          return device_it->second;
        }
      }
    }

    if (!create) {
      return nullptr;
    }

    BluetoothLEDevice device = nullptr;
    if (auto address = ParseBluetoothAddress(device_id)) {
      device = BluetoothLEDevice::FromBluetoothAddressAsync(*address).get();
    }
    if (!device) {
      try {
        device = BluetoothLEDevice::FromIdAsync(winrt::to_hstring(device_id)).get();
      } catch (...) {
        device = nullptr;
      }
    }
    if (device) {
      RememberDevice(device);
    }
    return device;
  }

  GattDeviceService ResolveService(const std::string& device_id,
                                   const std::string& service_uuid) {
    BluetoothLEDevice device = ResolveDevice(device_id, true);
    if (!device) {
      throw std::runtime_error("Device not found: " + device_id);
    }
    auto uuid = ParseGuid(service_uuid);
    if (!uuid) {
      throw std::invalid_argument("Invalid service UUID: " + service_uuid);
    }

    GattDeviceServicesResult result =
        device.GetGattServicesForUuidAsync(*uuid).get();
    if (result.Status() != GattCommunicationStatus::Success ||
        result.Services().Size() == 0) {
      throw std::runtime_error("GATT service not found: " + service_uuid);
    }
    return result.Services().GetAt(0);
  }

  GattCharacteristic ResolveCharacteristic(
      const std::string& device_id,
      const std::string& service_uuid,
      const std::string& characteristic_uuid) {
    const std::string key =
        CharacteristicKey(device_id, service_uuid, characteristic_uuid);
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      auto it = characteristic_cache_.find(key);
      if (it != characteristic_cache_.end()) {
        return it->second;
      }
    }

    auto uuid = ParseGuid(characteristic_uuid);
    if (!uuid) {
      throw std::invalid_argument("Invalid characteristic UUID: " + characteristic_uuid);
    }
    GattDeviceService service = ResolveService(device_id, service_uuid);
    GattCharacteristicsResult result =
        service.GetCharacteristicsForUuidAsync(*uuid).get();
    if (result.Status() != GattCommunicationStatus::Success ||
        result.Characteristics().Size() == 0) {
      throw std::runtime_error("GATT characteristic not found: " + characteristic_uuid);
    }
    GattCharacteristic characteristic = result.Characteristics().GetAt(0);
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      characteristic_cache_.insert_or_assign(key, characteristic);
    }
    return characteristic;
  }

  GattDescriptor ResolveDescriptor(const std::string& device_id,
                                   const std::string& service_uuid,
                                   const std::string& characteristic_uuid,
                                   const std::string& descriptor_uuid) {
    const std::string key = device_id + "|" + service_uuid + "|" +
                            characteristic_uuid + "|" + descriptor_uuid;
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      auto it = descriptor_cache_.find(key);
      if (it != descriptor_cache_.end()) {
        return it->second;
      }
    }

    auto uuid = ParseGuid(descriptor_uuid);
    if (!uuid) {
      throw std::invalid_argument("Invalid descriptor UUID: " + descriptor_uuid);
    }
    GattCharacteristic characteristic =
        ResolveCharacteristic(device_id, service_uuid, characteristic_uuid);
    GattDescriptorsResult result = characteristic.GetDescriptorsForUuidAsync(*uuid).get();
    if (result.Status() != GattCommunicationStatus::Success ||
        result.Descriptors().Size() == 0) {
      throw std::runtime_error("GATT descriptor not found: " + descriptor_uuid);
    }
    GattDescriptor descriptor = result.Descriptors().GetAt(0);
    {
      std::lock_guard<std::mutex> lock(device_mutex_);
      descriptor_cache_.insert_or_assign(key, descriptor);
    }
    return descriptor;
  }

  bool HasAnyService(const BluetoothLEDevice& device,
                     const std::vector<std::string>& service_uuids) {
    for (const auto& service_uuid : service_uuids) {
      auto uuid = ParseGuid(service_uuid);
      if (!uuid) {
        continue;
      }
      try {
        GattDeviceServicesResult result =
            device.GetGattServicesForUuidAsync(*uuid).get();
        if (result.Status() == GattCommunicationStatus::Success &&
            result.Services().Size() > 0) {
          return true;
        }
      } catch (...) {
      }
    }
    return false;
  }

  std::string RememberDevice(const BluetoothLEDevice& device) {
    const std::string key = DeviceKey(device);
    std::lock_guard<std::mutex> lock(device_mutex_);
    devices_.insert_or_assign(key, device);
    device_aliases_[HStringToString(device.DeviceId())] = key;
    if (device.BluetoothAddress() != 0) {
      device_aliases_[FormatBluetoothAddress(device.BluetoothAddress())] = key;
      device_aliases_[FormatBluetoothAddressDisplay(device.BluetoothAddress())] = key;
    }

    if (connection_tokens_.find(key) == connection_tokens_.end()) {
      connection_tokens_[key] = device.ConnectionStatusChanged(
          [weak_self = weak_from_this()](const BluetoothLEDevice& sender,
                                         const IInspectable&) {
            if (auto self = weak_self.lock()) {
              self->SendConnectionStateEvent(
                  self->DeviceKey(sender),
                  ConnectionStateString(sender.ConnectionStatus()),
                  std::nullopt);
            }
          });
    }
    return key;
  }

  std::string DeviceKey(const BluetoothLEDevice& device) const {
    if (!device) {
      return {};
    }
    return device.BluetoothAddress() == 0 ? HStringToString(device.DeviceId())
                                          : FormatBluetoothAddress(device.BluetoothAddress());
  }

  std::string CharacteristicKey(const std::string& device_id,
                                const std::string& service_uuid,
                                const std::string& characteristic_uuid) const {
    return device_id + "|" + ToLower(service_uuid) + "|" +
           ToLower(characteristic_uuid);
  }

  void SendAdapterStateEvent() {
    EncodableMap event;
    Put(event, "type", StringValue("adapterState"));
    Put(event, "state", StringValue(CurrentAdapterStateString()));
    SendEvent(std::move(event));
  }

  void SendConnectionStateEvent(const std::string& device_id,
                                const std::string& state,
                                std::optional<int32_t> status) {
    EncodableMap event;
    Put(event, "type", StringValue("connectionState"));
    Put(event, "deviceId", StringValue(device_id));
    Put(event, "state", StringValue(state));
    if (status) {
      Put(event, "status", EncodableValue(*status));
    }
    SendEvent(std::move(event));
  }

  void SendCharacteristicValueEvent(const std::string& device_id,
                                    const std::string& service_uuid,
                                    const std::string& characteristic_uuid,
                                    const std::vector<uint8_t>& value) {
    EncodableMap event;
    Put(event, "type", StringValue("characteristicValue"));
    Put(event, "deviceId", StringValue(device_id));
    Put(event, "serviceUuid", StringValue(service_uuid));
    Put(event, "characteristicUuid", StringValue(characteristic_uuid));
    Put(event, "value", ByteValue(value));
    SendEvent(std::move(event));
  }

  void SendDescriptorValueEvent(const std::string& device_id,
                                const std::string& service_uuid,
                                const std::string& characteristic_uuid,
                                const std::string& descriptor_uuid,
                                const std::vector<uint8_t>& value) {
    EncodableMap event;
    Put(event, "type", StringValue("descriptorValue"));
    Put(event, "deviceId", StringValue(device_id));
    Put(event, "serviceUuid", StringValue(service_uuid));
    Put(event, "characteristicUuid", StringValue(characteristic_uuid));
    Put(event, "descriptorUuid", StringValue(descriptor_uuid));
    Put(event, "value", ByteValue(value));
    SendEvent(std::move(event));
  }

  void SendAdvertisingState(bool is_advertising,
                            std::optional<int32_t> error_code,
                            const std::string& message) {
    EncodableMap event;
    Put(event, "type", StringValue("advertisingState"));
    Put(event, "isAdvertising", EncodableValue(is_advertising));
    if (error_code) {
      Put(event, "errorCode", EncodableValue(*error_code));
    }
    Put(event, "message", StringValue(message));
    SendEvent(std::move(event));
  }

  void SendEvent(EncodableMap event) {
    std::lock_guard<std::mutex> lock(event_mutex_);
    if (event_sink_) {
      event_sink_->Success(EncodableValue(std::move(event)));
    }
  }

  void ClearEventSink() {
    std::lock_guard<std::mutex> lock(event_mutex_);
    event_sink_.reset();
  }

  void CloseDevicesInternal() {
    std::lock_guard<std::mutex> lock(device_mutex_);
    for (auto& entry : subscriptions_) {
      try {
        entry.second.characteristic.ValueChanged(entry.second.token);
      } catch (...) {
      }
    }
    subscriptions_.clear();

    for (const auto& entry : connection_tokens_) {
      auto device = devices_.find(entry.first);
      if (device == devices_.end()) {
        continue;
      }
      try {
        device->second.ConnectionStatusChanged(entry.second);
      } catch (...) {
      }
    }
    connection_tokens_.clear();
    service_cache_.clear();
    characteristic_cache_.clear();
    descriptor_cache_.clear();
    devices_.clear();
    device_aliases_.clear();
  }

  struct CharacteristicSubscription {
    GattCharacteristic characteristic{nullptr};
    winrt::event_token token{};
  };

  mutable std::mutex event_mutex_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> event_sink_;

  mutable std::mutex scan_mutex_;
  BluetoothLEAdvertisementWatcher watcher_{nullptr};
  winrt::event_token received_token_{};
  winrt::event_token stopped_token_{};
  bool allow_duplicates_ = false;
  std::atomic<int> scan_generation_{0};
  std::unordered_set<std::string> seen_scan_devices_;
  std::unordered_map<std::string, int32_t> last_rssi_;

  mutable std::mutex device_mutex_;
  std::unordered_map<std::string, BluetoothLEDevice> devices_;
  std::unordered_map<std::string, std::string> device_aliases_;
  std::unordered_map<std::string, winrt::event_token> connection_tokens_;
  std::unordered_map<std::string, std::vector<GattDeviceService>> service_cache_;
  std::unordered_map<std::string, GattCharacteristic> characteristic_cache_;
  std::unordered_map<std::string, GattDescriptor> descriptor_cache_;
  std::unordered_map<std::string, CharacteristicSubscription> subscriptions_;
};

// static
void FlutterBluetoothPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), "flutter_bluetooth_plugin",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_channel =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "flutter_bluetooth_plugin/events",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterBluetoothPlugin>();
  auto* plugin_pointer = plugin.get();

  channel->SetMethodCallHandler(
      [plugin_pointer](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [plugin_pointer](const EncodableValue*,
                           std::unique_ptr<flutter::EventSink<EncodableValue>>&& events) {
            plugin_pointer->impl_->OnListen(std::move(events));
            return nullptr;
          },
          [plugin_pointer](const EncodableValue*) {
            plugin_pointer->impl_->OnCancel();
            return nullptr;
          }));

  registrar->AddPlugin(std::move(plugin));
}

FlutterBluetoothPlugin::FlutterBluetoothPlugin()
    : impl_(std::make_shared<Impl>()) {}

FlutterBluetoothPlugin::~FlutterBluetoothPlugin() = default;

void FlutterBluetoothPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  impl_->HandleMethodCall(method_call, std::move(result));
}

}  // namespace flutter_bluetooth_plugin
