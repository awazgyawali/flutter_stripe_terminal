part of stripe_terminal;

// {locationStatus: 1, batteryStatus: 0, originalJSON: {}, simulated: true, availableUpdate: false, locationId: st_simulated, serialNumber: WPC32SIMULATOR1, deviceType: 2}
class StripeReader {
  LocationStatus locationStatus;
  BatteryStatus batteryStatus;
  DeviceType deviceType;
  Map<String, dynamic> originalJSON;
  bool simulated, availableUpdate;
  String? locationId;
  String serialNumber;
  String? label;
  StripeReader({
    required this.locationStatus,
    required this.batteryStatus,
    required this.deviceType,
    required this.originalJSON,
    required this.simulated,
    required this.availableUpdate,
    required this.serialNumber,
    this.locationId,
    this.label,
  });

  static StripeReader fromJson(Map json) {
    return StripeReader(
      locationStatus: LocationStatus.values[json["locationStatus"]],
      batteryStatus: BatteryStatus.values[json["batteryStatus"]],
      deviceType: DeviceType.fromId(int.parse(json["deviceType"].toString())),
      originalJSON: Map.from(json["originalJSON"] ?? {}),
      simulated: json["simulated"],
      label: json["label"],
      availableUpdate: json["availableUpdate"],
      locationId: json["locationId"],
      serialNumber: json["serialNumber"],
    );
  }

  Map toJson() {
    return {
      "locationStatus": locationStatus.index,
      "batteryStatus": batteryStatus.index,
      "deviceType": deviceType.index,
      "originalJSON": Map.from(originalJSON),
      "simulated": simulated,
      "availableUpdate": availableUpdate,
      "locationId": locationId,
      "serialNumber": serialNumber,
    };
  }
}

enum LocationStatus {
  unknown,

  set,

  notSet,
}

enum BatteryStatus {
  /// Battery state is not yet known or not available for the connected reader.
  unknown,

  /// The device's battery is less than or equal to 5%.
  critical,

  /// The device's battery is between 5% and 20%.
  low,

  /// The device's battery is greater than 20%.
  nominal,
}

enum DeviceType {
  chipper2X(0),
  verifoneP400(1),
  wisePad3(2),
  stripeM2(3),
  wisePosE(4),
  wisePosEDevKit(5),
  stripeS700(9),
  stripeS700DevKit(10),
  appleBuiltIn(11);

  const DeviceType(this.deviceType);

  factory DeviceType.fromId(int id) {
    return values.firstWhere((element) => element.deviceType == id);
  }

  final int deviceType;
}

enum ConnectionStatus { notConnected, connected, connecting }
