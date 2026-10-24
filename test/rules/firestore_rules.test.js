/**
 * Unit tests for Firestore Security Rules using @firebase/rules-unit-testing.
 *
 * To run these tests locally:
 * 1. Ensure JDK 21+ is installed for Firebase Emulator.
 * 2. npm install --save-dev @firebase/rules-unit-testing mocha
 * 3. npx firebase-tools emulators:exec --only firestore "npx mocha test/rules/firestore_rules.test.js"
 */

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');

const PROJECT_ID = 'roadsense-test-project';

describe('RoadSense Firestore Security Rules Unit Tests', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync('firestore.rules', 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  afterEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  describe('users/{uid} access policy', () => {
    it('allows a user to read and create their own profile', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');
      await assertSucceeds(
        alice.firestore().collection('users').doc('alice_uid').set({
          uid: 'alice_uid',
          displayName: 'Alice Driver',
          email: 'alice@example.com',
          role: 'user',
        })
      );

      await assertSucceeds(
        alice.firestore().collection('users').doc('alice_uid').get()
      );
    });

    it('denies a user from reading another user profile', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');
      const bob = testEnv.authenticatedContext('bob_uid');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('bob_uid').set({
          uid: 'bob_uid',
          displayName: 'Bob Driver',
          email: 'bob@example.com',
          role: 'user',
        });
      });

      await assertFails(
        alice.firestore().collection('users').doc('bob_uid').get()
      );
    });

    it('denies a user from self-escalating role to administrator', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');

      // Attempting to create an admin profile directly
      await assertFails(
        alice.firestore().collection('users').doc('alice_uid').set({
          uid: 'alice_uid',
          displayName: 'Alice Driver',
          email: 'alice@example.com',
          role: 'administrator', // Privilege escalation forbidden
        })
      );
    });
  });

  describe('trips/{tripId} ownership policy', () => {
    it('allows a user to create and read their own trips', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');
      await assertSucceeds(
        alice.firestore().collection('trips').doc('trip_1').set({
          tripId: 'trip_1',
          ownerUid: 'alice_uid',
          startedAt: '2026-10-24T08:00:00Z',
          distanceKm: 12.5,
        })
      );

      await assertSucceeds(
        alice.firestore().collection('trips').doc('trip_1').get()
      );
    });

    it('denies a user from reading another users trips', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');
      const bob = testEnv.authenticatedContext('bob_uid');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc('bob_trip').set({
          tripId: 'bob_trip',
          ownerUid: 'bob_uid',
          startedAt: '2026-10-24T08:00:00Z',
        });
      });

      await assertFails(
        alice.firestore().collection('trips').doc('bob_trip').get()
      );
    });
  });

  describe('hazards/{hazardId} trusted lifecycle policy', () => {
    it('allows authenticated users to read hazards for map navigation', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('hazards').doc('hazard_blr_1').set({
          hazardId: 'hazard_blr_1',
          latitude: 12.97,
          longitude: 77.59,
          type: 'pothole',
          status: 'verified',
        });
      });

      await assertSucceeds(
        alice.firestore().collection('hazards').doc('hazard_blr_1').get()
      );
    });

    it('denies ordinary clients from creating or confirming hazards directly', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');

      // Attempting client-side hazard creation
      await assertFails(
        alice.firestore().collection('hazards').doc('fake_hazard').set({
          hazardId: 'fake_hazard',
          latitude: 12.97,
          longitude: 77.59,
          type: 'pothole',
          status: 'verified', // Ordinary client cannot confirm hazard!
        })
      );
    });

    it('allows verified reviewer to update hazard status', async () => {
      const reviewer = testEnv.authenticatedContext('reviewer_uid', {
        role: 'reviewer',
      });

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('hazards').doc('hazard_blr_2').set({
          hazardId: 'hazard_blr_2',
          latitude: 12.97,
          longitude: 77.59,
          status: 'possible',
        });
      });

      await assertSucceeds(
        reviewer.firestore().collection('hazards').doc('hazard_blr_2').update({
          status: 'verified',
        })
      );
    });
  });

  describe('reports/{reportId} validation & sanitization', () => {
    it('rejects reports with invalid coordinates', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');

      await assertFails(
        alice.firestore().collection('reports').doc('bad_report').set({
          reportId: 'bad_report',
          reporterUid: 'alice_uid',
          latitude: 95.0, // Invalid latitude > 90
          longitude: 77.59,
          status: 'submitted',
        })
      );
    });

    it('rejects reports with local device file paths', async () => {
      const alice = testEnv.authenticatedContext('alice_uid');

      await assertFails(
        alice.firestore().collection('reports').doc('local_file_report').set({
          reportId: 'local_file_report',
          reporterUid: 'alice_uid',
          latitude: 12.97,
          longitude: 77.59,
          status: 'submitted',
          photoUrl: 'file:///data/user/0/com.roadsense/cache/photo.jpg',
        })
      );
    });
  });
});
