part of stripe_terminal;

class StripePaymentIntent {
  final String id;
  final num amount;
  final num amountCapturable;
  final num amountReceived;
  final String? application;
  final num? applicationFeeAmount;
  final String? captureMethod;
  final String? cancellationReason;
  final int? canceledAt;
  final String? clientSecret;
  final String? confirmationMethod;
  final int created;
  final String? currency;
  final String? customer;
  final String? description;
  final String? invoice;
  final bool livemode;
  final Map<String, dynamic> metadata;
  final String? onBehalfOf;
  final String? paymentMethodId;
  final PaymentIntentStatus status;
  final String? review;
  final String? receiptEmail;
  final String? setupFutureUsage;
  final String? transferGroup;
  StripePaymentIntent({
    required this.id,
    required this.amount,
    required this.amountCapturable,
    required this.amountReceived,
    required this.created,
    required this.status,
    this.applicationFeeAmount,
    this.livemode = true,
    this.metadata = const {},
    this.application,
    this.captureMethod,
    this.cancellationReason,
    this.canceledAt,
    this.clientSecret,
    this.confirmationMethod,
    this.currency,
    this.customer,
    this.description,
    this.invoice,
    this.onBehalfOf,
    this.paymentMethodId,
    this.review,
    this.receiptEmail,
    this.setupFutureUsage,
    this.transferGroup,
  });

  static StripePaymentIntent fromMap(Map data) {
    return StripePaymentIntent(
      id: data["id"],
      amount: data["amount"],
      amountCapturable: data["amount_capturable"],
      amountReceived: data["amount_received"],
      application: data["application"],
      applicationFeeAmount: data["application_fee_amount"],
      captureMethod: data["capture_method"],
      cancellationReason: data["cancellation_reason"],
      canceledAt: data["canceled_at"],
      clientSecret: data["client_secret"],
      confirmationMethod: data["confirmation_method"],
      created: data["created"],
      currency: data["currency"],
      customer: data["customer"],
      description: data["description"],
      invoice: data["invoice"],
      livemode: data["livemode"],
      metadata: Map.from(data["metadata"] ?? {}),
      onBehalfOf: data["on_behalf_of"],
      paymentMethodId: data["payment_method_id"],
      review: data["review"],
      receiptEmail: data["receipt_email"],
      setupFutureUsage: data["setup_future_usage"],
      transferGroup: data["transfer_group"],
      status: getPaymentIntentStatus(data["status"]),
    );
  }
}

PaymentIntentStatus getPaymentIntentStatus(String name) {
  switch (name) {
    case "canceled":
      return PaymentIntentStatus.canceled;
    case "requires_payment_method":
      return PaymentIntentStatus.requiresPaymentMethod;
    case "requires_confirmation":
      return PaymentIntentStatus.requiresConfirmation;
    case "requires_action":
      return PaymentIntentStatus.requiresAction;
    case "processing":
      return PaymentIntentStatus.processing;
    case "succeeded":
      return PaymentIntentStatus.succeeded;
    case "requires_capture":
      return PaymentIntentStatus.requiresCapture;
    default:
      return PaymentIntentStatus.unknown;
  }
}

enum PaymentIntentStatus {
  canceled,
  requiresCapture,
  requiresAction,
  processing,
  requiresConfirmation,
  requiresPaymentMethod,
  succeeded,
  unknown
}
