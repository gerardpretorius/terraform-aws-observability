# Copyright (C) 2020 Nicolas Lamirault <nicolas.lamirault@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_secretsmanager_secret_version.oidc_url.secret_binary, "https://", "")}:sub"
      values   = formatlist("system:serviceaccount:%s:%s", var.namespace, var.service_accounts)
    }

    principals {
      identifiers = [data.aws_secretsmanager_secret_version.oidc_arn.secret_binary]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "thanos" {
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  name               = local.service_name
  tags               = var.tags
}

data "aws_iam_policy_document" "thanos_permissions" {
  statement {
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.thanos.arn,
      "${aws_s3_bucket.thanos.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "thanos_permissions" {
  name        = local.service_name
  path        = "/"
  description = "Permissions for Thanos"
  policy      = data.aws_iam_policy_document.thanos_permissions.json
}

resource "aws_iam_role_policy_attachment" "thanos" {
  role       = aws_iam_role.thanos.name
  policy_arn = aws_iam_policy.thanos_permissions.arn
}
