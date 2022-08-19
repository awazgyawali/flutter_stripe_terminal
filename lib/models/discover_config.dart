part of stripe_terminal;

enum DiscoveryMethod {
  /// To discover `bluetooth` based readers.
  bluetooth,

  /// To discover `internet` based readers.
  internet,

  /// To discover `localMobile` based readers.
  localMobile,

  /// To discover `handOff` based readers.
  handOff,

  /// To discover `embedded` based readers.
  embedded,

  /// To discover `usb` based readers.
  usb,
}

class DiscoverConfig {
  final DiscoveryMethod discoveryMethod;
  final bool simulated;
  final String? locationId;

  DiscoverConfig({
    /// The method of discovery. It can be `bluetooth`,`internet`,`localMobile`,`handOff`,`embedded` or`usb`.
    ///
    /// Its a required field
    required this.discoveryMethod,

    /// Id of the location where you want to initate the discovery.
    ///
    /// Mostly requred on bluetooth reader
    this.locationId,

    /// Weather to show simulated devices in the discovery process.
    ///
    /// Defaults to `false`
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
