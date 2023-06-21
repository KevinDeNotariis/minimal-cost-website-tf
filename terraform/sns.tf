resource "aws_sns_topic" "this" {
  name = "${var.identifier}-${var.suffix}"
}

resource "aws_sns_topic_subscription" "this" {
  for_each = toset(var.sns_email_subscriptions)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.key
}
