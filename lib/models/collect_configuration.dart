part of stripe_terminal;

class CollectConfiguration {
  final bool skipTipping;
  const CollectConfiguration({
    required this.skipTipping,
  });

  toMap() {
    return {
      "skipTipping": skipTipping,
    };
  }
}
