import 'package:ace_naplan5/domain/answer_rule.dart';
import 'package:ace_naplan5/domain/question.dart';
import 'package:ace_naplan5/infrastructure/persistence/content_import_plan.dart';
import 'package:flutter_test/flutter_test.dart';

// Synthetic metadata fixtures exercise planning only; no content is approved here.
BankIdentity bank(String version, String digest,
        {int schema = 1, int? sequence}) =>
    BankIdentity(
        bankSequence: sequence ??
            (version == 'v1'
                ? 1
                : version == 'v3'
                    ? 3
                    : 2),
        version: version,
        schemaVersion: schema,
        digest: digest);

QuestionRevision question(
  String id, {
  String version = 'v2',
  int revision = 1,
  String digest = 'item-digest',
  int schema = 1,
}) =>
    QuestionRevision(
      itemId: id,
      variantId: 'variant-$id',
      familyId: 'family-$id',
      revision: revision,
      contentSchemaVersion: schema,
      bankVersion: version,
      topic: 'topic',
      domain: QuestionDomain.numeracy,
      difficulty: QuestionDifficulty.introductory,
      curriculumReferences: const ['reference'],
      skillReferences: const ['skill'],
      provenance: 'publisher',
      license: 'license',
      contentDigest: digest,
      reviewRecordId: 'review-record',
      prompt: 'Prompt',
      stimulusDescription: 'Description',
      hint: 'Hint',
      explanation: 'Explanation',
      assets: const [],
      answerRule: SingleChoiceRule(
        options: [
          ChoiceOption(id: 'a', label: 'A'),
          ChoiceOption(id: 'b', label: 'B'),
        ],
        correctOptionId: 'a',
        scoringPolicyVersion: 1,
      ),
    );

StoredRevisionDigest stored(String id, int revision, String digest) =>
    StoredRevisionDigest(itemId: id, revision: revision, digest: digest);

ContentImportPlan plan({
  required BankIdentity incoming,
  required List<QuestionRevision> questions,
  BankIdentity? active,
  List<BankMembership> membership = const [],
  List<StoredRevisionDigest> existing = const [],
}) =>
    planContentImport(
      incomingBank: incoming,
      incomingRevisions: questions,
      activeBank: active,
      activeMembership: membership,
      storedRevisions: existing,
      supportedSchemaVersion: 1,
    );

void rejects(
  ContentImportConflictReason reason,
  void Function() operation,
) {
  expect(
    operation,
    throwsA(isA<ContentImportConflict>().having(
      (error) => error.reason,
      'reason',
      reason,
    )),
  );
}

void main() {
  test('new bank inserts missing revisions and replaces membership only', () {
    final incoming = bank('v2', 'manifest-2');
    final old = bank('v1', 'manifest-1');
    final q1 = question('retained', version: 'v2', revision: 2);
    final q2 = question('new');
    final questions = [q1, q2];
    final existing = [
      stored('retained', 1, 'historical'),
      stored('retained', 2, 'item-digest'),
      stored('retired', 1, 'old-digest'),
    ];

    final result = plan(
      incoming: incoming,
      questions: questions,
      active: old,
      membership: const [
        BankMembership('retained', 1),
        BankMembership('retired', 1)
      ],
      existing: existing,
    );
    expect(result.isNoOp, isFalse);
    expect(result.missingRevisions, [same(q2)]);
    expect(result.membership.map((entry) => entry.itemId), [
      'retained',
      'new',
    ]);
    expect(result.manifestToActivate, same(incoming));
    expect(questions, [q1, q2]);
    expect(existing.length, 3); // Historical rows stay in caller state.
    expect(() => result.missingRevisions.clear(), throwsUnsupportedError);
    expect(() => result.membership.clear(), throwsUnsupportedError);
    questions.clear();
    existing.clear();
    expect(result.missingRevisions, [same(q2)]);
    expect(result.membership.length, 2);
  });

  test('identical bank is a no-op after revision consistency checks', () {
    final identity = bank('v2', 'manifest-2');
    final q = question('one');
    final result = plan(
      incoming: identity,
      questions: [q],
      active: bank('v2', 'manifest-2'),
      membership: const [BankMembership('one', 1)],
      existing: [stored('one', 1, 'item-digest')],
    );
    expect(result.isNoOp, isTrue);
    expect(result.missingRevisions, isEmpty);
    expect(result.membership, isEmpty);
    expect(result.manifestToActivate, isNull);
    expect(() => result.membership.add(const BankMembership('x', 1)),
        throwsUnsupportedError);
  });

  test('same-version changed digest and incomplete active bank fail', () {
    final identity = bank('v2', 'manifest-2');
    final q = question('one');
    rejects(
      ContentImportConflictReason.bankDigestChanged,
      () => plan(
        incoming: identity,
        questions: [q],
        active: bank('v2', 'other-digest'),
        membership: const [BankMembership('one', 1)],
        existing: [stored('one', 1, 'item-digest')],
      ),
    );
    rejects(
      ContentImportConflictReason.incompleteActiveBank,
      () => plan(incoming: identity, questions: [q], active: identity),
    );
  });

  test('immutable revision digest conflicts also fail on no-op path', () {
    final identity = bank('v2', 'manifest-2');
    rejects(
      ContentImportConflictReason.revisionDigestChanged,
      () => plan(
        incoming: identity,
        questions: [question('one')],
        active: identity,
        membership: const [BankMembership('one', 1)],
        existing: [stored('one', 1, 'different')],
      ),
    );
  });

  test('duplicate membership and stored revision metadata fail', () {
    final incoming = bank('v2', 'manifest-2');
    rejects(
      ContentImportConflictReason.duplicateMembership,
      () => plan(incoming: incoming, questions: [
        question('one'),
        question('one', revision: 2),
      ]),
    );
    rejects(
      ContentImportConflictReason.duplicateRevision,
      () => plan(
        incoming: incoming,
        questions: [question('one')],
        existing: [
          stored('one', 1, 'item-digest'),
          stored('one', 1, 'item-digest'),
        ],
      ),
    );
  });

  test('bank sequence rejects downgrade, aliases and version reuse', () {
    final active = bank('v3', 'manifest-3');
    rejects(
        ContentImportConflictReason.bankDowngrade,
        () => plan(
            incoming: bank('v2', 'manifest-2'),
            questions: [question('one')],
            active: active));
    rejects(
        ContentImportConflictReason.bankSequenceConflict,
        () => plan(
            incoming: bank('alias', 'manifest', sequence: 3),
            questions: [question('one', version: 'alias')],
            active: active));
    rejects(
        ContentImportConflictReason.bankSequenceConflict,
        () => plan(
            incoming: bank('v3', 'manifest-3', sequence: 4),
            questions: [question('one', version: 'v3')],
            active: active));
    rejects(ContentImportConflictReason.invalidMetadata,
        () => bank('v2', 'manifest-2', sequence: 0));
  });

  test('same identity requires exact active membership regardless of order',
      () {
    final identity = bank('v2', 'manifest-2');
    final questions = [question('one'), question('two')];
    final existing = [
      stored('one', 1, 'item-digest'),
      stored('one', 2, 'older-or-alternate'),
      stored('two', 1, 'item-digest'),
      stored('extra', 1, 'item-digest')
    ];
    final result = plan(
        incoming: identity,
        questions: questions,
        active: identity,
        membership: const [BankMembership('two', 1), BankMembership('one', 1)],
        existing: existing);
    expect(result.isNoOp, isTrue);
    for (final members in [
      const [BankMembership('one', 1)],
      const [
        BankMembership('one', 1),
        BankMembership('two', 1),
        BankMembership('extra', 1)
      ],
      const [BankMembership('one', 2), BankMembership('two', 1)],
    ]) {
      rejects(
          ContentImportConflictReason.incompleteActiveBank,
          () => plan(
              incoming: identity,
              questions: questions,
              active: identity,
              membership: members,
              existing: existing));
    }
  });

  test('invalid, duplicate and orphan active membership fail closed', () {
    final incoming = bank('v2', 'manifest-2');
    final questions = [question('one')];
    rejects(
        ContentImportConflictReason.invalidMetadata,
        () => plan(
            incoming: incoming,
            questions: questions,
            membership: const [BankMembership('one', 1)]));
    rejects(
        ContentImportConflictReason.invalidMetadata,
        () => plan(
            incoming: incoming,
            questions: questions,
            active: incoming,
            membership: const [BankMembership(' ', 1)]));
    rejects(
        ContentImportConflictReason.invalidMetadata,
        () => plan(
            incoming: incoming,
            questions: questions,
            active: incoming,
            membership: const [BankMembership('one', 0)]));
    rejects(
        ContentImportConflictReason.duplicateMembership,
        () => plan(
                incoming: incoming,
                questions: questions,
                active: incoming,
                membership: const [
                  BankMembership('one', 1),
                  BankMembership('one', 2)
                ],
                existing: [
                  stored('one', 1, 'item-digest'),
                  stored('one', 2, 'other')
                ]));
    rejects(
        ContentImportConflictReason.incompleteActiveBank,
        () => plan(
            incoming: incoming,
            questions: questions,
            active: incoming,
            membership: const [BankMembership('one', 1)]));
  });

  test('unsupported schemas and invalid identity or records fail', () {
    rejects(
      ContentImportConflictReason.unsupportedSchema,
      () => plan(incoming: bank('v2', 'digest', schema: 2), questions: [
        question('one', schema: 2),
      ]),
    );
    rejects(
      ContentImportConflictReason.unsupportedSchema,
      () => plan(
        incoming: bank('v2', 'digest'),
        questions: [question('one')],
        active: bank('v1', 'old', schema: 2),
      ),
    );
    rejects(
      ContentImportConflictReason.invalidMetadata,
      () => bank(' ', 'digest'),
    );
    rejects(
      ContentImportConflictReason.invalidMetadata,
      () => stored('one', 1, ' '),
    );
    rejects(
      ContentImportConflictReason.invalidMetadata,
      () => plan(incoming: bank('v2', 'digest'), questions: const []),
    );
    rejects(
      ContentImportConflictReason.invalidMetadata,
      () => plan(incoming: bank('v2', 'digest'), questions: [
        question('one', version: 'v3'),
      ]),
    );
  });
}
