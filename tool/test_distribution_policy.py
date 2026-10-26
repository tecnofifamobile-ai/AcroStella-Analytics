import json,tempfile,unittest
from pathlib import Path
from distribution_policy import require_public_distribution
class DistributionPolicyTests(unittest.TestCase):
 def test_private_builds_block_both_public_publishers_before_network_mutation(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder)
   (root/'distribution-policy.json').write_text(json.dumps({'mode':'private-only'}))
   with self.assertRaisesRegex(ValueError,'uso privado'):require_public_distribution(root)
 def test_absent_policy_preserves_legacy_publisher_behavior(self):
  with tempfile.TemporaryDirectory() as folder:require_public_distribution(Path(folder))

 def test_ios_only_native_engine_does_not_block_authorized_android_installers(self):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder)
   (root/'distribution-policy.json').write_text(json.dumps({'mode':'platform-specific','platforms':{'android':'public-installers','ios':'source-approval-required'}}))
   require_public_distribution(root,platform='android')
   with self.assertRaisesRegex(ValueError,'código fuente'):require_public_distribution(root,platform='ios')
   with self.assertRaises(ValueError):require_public_distribution(root)
