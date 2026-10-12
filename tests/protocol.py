"""Exercise the real stdio server without connecting to a running game."""
import json
import pathlib
import subprocess
import unittest

BINARY = pathlib.Path(__file__).resolve().parents[1] / 'build/palworld-mcp'


def exchange(messages):
    rows = [m if isinstance(m, str) else json.dumps(m) for m in messages]
    result = subprocess.run([str(BINARY), '--socket', '/tmp/palworld-mcp-test-missing.sock'],
                            input='\n'.join(rows) + '\n', text=True, capture_output=True, timeout=10, check=True)
    assert not result.stderr, result.stderr
    return [json.loads(line) for line in result.stdout.splitlines()]


def request(method, ident=1, **params):
    return {'jsonrpc': '2.0', 'id': ident, 'method': method, 'params': params}


class ProtocolTests(unittest.TestCase):
    def test_handshake_and_tools(self):
        rows = exchange([request('initialize', protocolVersion='2025-11-25'),
                         {'jsonrpc': '2.0', 'method': 'notifications/initialized'}, request('tools/list', 2)])
        self.assertEqual(rows[0]['result']['protocolVersion'], '2025-11-25')
        tools = rows[1]['result']['tools']
        self.assertGreaterEqual(len(tools), 24)
        self.assertEqual(len({tool['name'] for tool in tools}), len(tools))
        self.assertTrue(all(tool['inputSchema']['additionalProperties'] is False for tool in tools))

    def test_lifecycle_and_invalid_frames(self):
        rows = exchange(['{', 'true', request('tools/list'), request('ping', True)])
        self.assertEqual([r['error']['code'] for r in rows], [-32700, -32600, -32000, -32600])

    def test_argument_validation_precedes_connection(self):
        rows = exchange([request('initialize'), {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
                         request('tools/call', 2, name='palworld_move', arguments={'seconds': 30}),
                         request('tools/call', 3, name='palworld_move', arguments={'forward': True}),
                         request('tools/call', 4, name='palworld_state', arguments={})])
        self.assertTrue(all(row['result']['isError'] for row in rows[1:]))
        self.assertIn('out of range', rows[1]['result']['content'][0]['text'])
        self.assertIn('out of range', rows[2]['result']['content'][0]['text'])
        self.assertIn('Open Palworld', rows[3]['result']['content'][0]['text'])


if __name__ == '__main__':
    unittest.main()
