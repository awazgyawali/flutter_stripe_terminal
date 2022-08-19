part of stripe_terminal;

class CollectConfiguration {
  final bool skipTipping;
  const CollectConfiguration({
    /// Weather to skip tipping or not, default to false if config is not provided
    required this.skipTipping,
  });

  toMap() {
    return {
      "skipTipping": skipTipping,
    };
  }
}
