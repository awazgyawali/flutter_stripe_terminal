part of stripe_terminal;

class StripePaymentMethod {
  StripePaymentMethod({
    required this.id,
    required this.metadata,
    required this.billingDetails,
    required this.object,
    required this.created,
    required this.livemode,
    required this.type,
    this.card,
    this.customer,
  });

  String id;
  String object;
  BillingDetails billingDetails;
  Card? card;
  int created;
  String? customer;
  bool livemode;
  Map? metadata;
  String type;

  factory StripePaymentMethod.fromJson(Map json) {
    return StripePaymentMethod(
      id: json["id"],
      object: json["object"],
      billingDetails: BillingDetails.fromJson(json["billing_details"]),
      card: json["card"] != null ? Card.fromJson(json["card"]) : null,
      created: json["created"],
      customer: json["customer"],
      livemode: json["livemode"],
      metadata: json["metadata"],
      type: json["type"],
    );
  }
  Map toJson() => {
        "id": id,
        "object": object,
        "billing_details": billingDetails.toJson(),
        "card": card?.toJson(),
        "created": created,
        "customer": customer,
        "livemode": livemode,
        "metadata": metadata,
        "type": type,
      };
}

class BillingDetails {
  BillingDetails({
    this.address,
    this.email,
    this.name,
    this.phone,
  });

  Address? address;
  String? email, name, phone;

  factory BillingDetails.fromJson(Map json) => BillingDetails(
        address:
            json["address"] != null ? Address.fromJson(json["address"]) : null,
        email: json["email"],
        name: json["name"],
        phone: json["phone"],
      );

  Map toJson() => {
        "address": address?.toJson(),
        "email": email,
        "name": name,
        "phone": phone,
      };
}

class Address {
  Address({
    this.city,
    this.country,
    this.line1,
    this.line2,
    this.postalCode,
    this.state,
  });

  String? city, country, line1, line2, postalCode, state;

  factory Address.fromJson(Map json) => Address(
        city: json["city"],
        country: json["country"],
        line1: json["line1"],
        line2: json["line2"],
        postalCode: json["postal_code"],
        state: json["state"],
      );

  Map toJson() => {
        "city": city,
        "country": country,
        "line1": line1,
        "line2": line2,
        "postal_code": postalCode,
        "state": state,
      };
}

class Card {
  Card({
    required this.brand,
    required this.country,
    required this.expMonth,
    required this.expYear,
    required this.fingerprint,
    required this.funding,
    required this.last4,
    this.networks,
  });

  String brand;
  String country;
  int expMonth;
  int expYear;
  String fingerprint;
  String funding;
  String last4;
  Networks? networks;

  factory Card.fromJson(Map json) => Card(
        brand: json["brand"],
        country: json["country"],
        expMonth: json["exp_month"],
        expYear: json["exp_year"],
        fingerprint: json["fingerprint"],
        funding: json["funding"],
        last4: json["last4"],
        networks: json["networks"] != null
            ? Networks.fromJson(json["networks"])
            : null,
      );

  Map toJson() => {
        "brand": brand,
        "country": country,
        "exp_month": expMonth,
        "exp_year": expYear,
        "fingerprint": fingerprint,
        "funding": funding,
        "last4": last4,
        "networks": networks?.toJson(),
      };
}

class Networks {
  Networks({
    required this.available,
    this.preferred,
  });

  List<String> available;
  String? preferred;

  factory Networks.fromJson(Map json) => Networks(
        available: List<String>.from(json["available"].map((x) => x)),
        preferred: json["preferred"],
      );

  Map toJson() => {
        "available": List<dynamic>.from(available.map((x) => x)),
        "preferred": preferred,
      };
}

class ThreeDSecureUsage {
  ThreeDSecureUsage({
    required this.supported,
  });

  bool supported;

  factory ThreeDSecureUsage.fromJson(Map json) => ThreeDSecureUsage(
        supported: json["supported"],
      );

  Map toJson() => {
        "supported": supported,
      };
}
