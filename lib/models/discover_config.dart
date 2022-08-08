part of stripe_terminal;

enum DiscoveryMethod {
  bluetooth,
  internet,
  localMobile,
  handOff,
  embedded,
  usb,
}

class DiscoverConfig {
  final DiscoveryMethod discoveryMethod;
  final bool simulated;
  final String? locationId;

  DiscoverConfig({
    required this.discoveryMethod,
    this.locationId,
    this.simulated = false,
  });

  toMap() {
    return {
      "discoveryMethod": describeEnum(discoveryMethod),
      "locationId": locationId,
      "simulated": simulated,
    };
  }
}
