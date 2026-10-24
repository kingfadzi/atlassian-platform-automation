# Stage: foundation, part 3. Hands the catalogue, the facts and the intent values to the
# generic evaluation. Nothing about individual controls is decided in this stage's HCL.

locals {
  catalogue = yamldecode(file("${path.module}/../../policy/foundation.yaml"))
  now       = plantimestamp()
  intent    = { for k, v in var.foundation : "foundation.${k}" => v }
}

module "evaluation" {
  source    = "../../modules/control_evaluation"
  catalogue = local.catalogue
  facts     = local.facts
  intent    = local.intent
  now       = local.now
}

locals {
  verdict  = module.evaluation.verdict
  blocking = module.evaluation.blocking
  findings = module.evaluation.findings
  ready    = module.evaluation.ready
}
