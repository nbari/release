#!/usr/bin/env python3
"""Check Marketplace metadata and the existing composite Action contract.

Optional argument: an action.yml extracted from the intended release revision.
PyYAML is a test-only dependency; the Action itself still uses Bash, Git and jq.
"""
from pathlib import Path
import sys
import unittest

import yaml

METADATA = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / "action.yml"


def check_description(description):
    if not isinstance(description, str) or not description.strip():
        raise ValueError("Action description must be a nonempty string")
    if len(description) >= 125:
        raise ValueError(f"Action description must be less than 125 characters (got {len(description)})")


class ActionMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.metadata = yaml.safe_load(METADATA.read_text(encoding="utf-8"))
        if not isinstance(cls.metadata, dict):
            raise ValueError("Action metadata must be a YAML mapping")

    def test_description(self):
        check_description(self.metadata.get("description"))

    def test_description_boundary_and_missing_values(self):
        check_description("x" * 124)
        for value in (None, "", "   ", 125, "x" * 125, "x" * 126):
            with self.subTest(value=value), self.assertRaises(ValueError):
                check_description(value)

    def test_name(self):
        self.assertEqual(self.metadata.get("name"), "Release Flow Provenance")

    def test_branding(self):
        # shield and blue are supported GitHub branding values; preserve both.
        self.assertEqual(self.metadata.get("branding"), {"icon": "shield", "color": "blue"})

    def test_inputs(self):
        inputs = self.metadata["inputs"]
        self.assertEqual(set(inputs), {"operation", "project-directory", "adapter"})
        for key, default in (("operation", "validate"), ("project-directory", "."), ("adapter", "")):
            with self.subTest(input=key):
                self.assertIs(inputs[key]["required"], False)
                self.assertEqual(inputs[key]["default"], default)
                self.assertIsInstance(inputs[key]["description"], str)
                self.assertTrue(inputs[key]["description"].strip())

    def test_outputs(self):
        outputs = self.metadata["outputs"]
        self.assertEqual(set(outputs), {"project", "project-directory", "adapter", "runtime-revision", "validation-json"})
        for key, output in outputs.items():
            with self.subTest(output=key):
                self.assertEqual(output["value"], "${{ steps.validate.outputs." + key + " }}")
                self.assertIsInstance(output["description"], str)
                self.assertTrue(output["description"].strip())

    def test_composite_runtime(self):
        self.assertEqual(self.metadata["runs"], {
            "using": "composite",
            "steps": [{
                "id": "validate", "shell": "bash",
                "env": {
                    "RF_ACTION_PATH": "${{ github.action_path }}",
                    "RF_ACTION_REF": "${{ github.action_ref }}",
                    "RF_INPUT_OPERATION": "${{ inputs.operation }}",
                    "RF_INPUT_PROJECT_DIRECTORY": "${{ inputs.project-directory }}",
                    "RF_INPUT_ADAPTER": "${{ inputs.adapter }}",
                },
                "run": 'bash "${RF_ACTION_PATH}/scripts/action.sh"',
            }],
        })


if __name__ == "__main__":
    unittest.main(verbosity=2)
