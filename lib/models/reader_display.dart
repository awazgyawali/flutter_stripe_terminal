part of stripe_terminal;

enum DisplayType {
  cart,
}

class ReaderDisplay {
  final DisplayType type;
  final DisplayCart cart;

  ReaderDisplay({
    required this.type,
    required this.cart,
  });

  toMap() {
    return {
      "type": describeEnum(type),
      "cart": cart.toMap(),
    };
  }
}

class DisplayCart {
  final String currency;
  final int tax, total;
  final List<DisplayLineItem> lineItems;

  DisplayCart({
    required this.currency,
    required this.tax,
    required this.total,
    required this.lineItems,
  });

  toMap() {
    return {
      "currency": currency,
      "tax": tax,
      "total": total,
      "lineItems": lineItems.map((e) => e.toMap()).toList(),
    };
  }
}

class DisplayLineItem {
  final String description;
  final int quantity, amount;

  DisplayLineItem({
    required this.description,
    required this.quantity,
    required this.amount,
  });

  toMap() {
    return {
      "description": description,
      "quantity": quantity,
      "amount": amount,
    };
  }
}
