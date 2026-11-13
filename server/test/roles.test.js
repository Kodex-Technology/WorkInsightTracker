import test from 'node:test';
import assert from 'node:assert/strict';
import {
  mergeClaims,
  normalizeRole,
  isAdminRole,
} from '../src/roles.js';

test('normalizeRole defaults unknown to user', () => {
  assert.equal(normalizeRole(''), 'user');
  assert.equal(normalizeRole('SUPER_ADMIN'), 'super_admin');
  assert.equal(normalizeRole('nope'), 'user');
});

test('mergeClaims preserves unrelated claims', () => {
  const merged = mergeClaims({ beta: true, role: 'user' }, 'admin');
  assert.equal(merged.role, 'admin');
  assert.equal(merged.beta, true);
});

test('isAdminRole', () => {
  assert.equal(isAdminRole('admin'), true);
  assert.equal(isAdminRole('super_admin'), true);
  assert.equal(isAdminRole('user'), false);
});
