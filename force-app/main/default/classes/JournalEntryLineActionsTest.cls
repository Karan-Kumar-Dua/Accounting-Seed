@IsTest
public class JournalEntryLineActionsTest {
	@testSetup
	private static void setupTestData() {
		TestDataSuite.getInstance(true);
	}

	@IsTest
	public static void testGLAccountIsRequired() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.GL_Account__c = null;

			DMLException dmlEx;
			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
		}
	}

	@IsTest
	public static void testValidatePayeeSetCorrectWhenAR() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AR_CONTROL_GL_ACCOUNT)
				?.GL_Account__c;
			jEntryLine.Account__c = null;
			jEntryLine.Contact__c = null;
			jEntryLine.Employee__c = null;

			DMLException dmlEx;
			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(JournalEntryLineActions.ACCOUNT_NOT_EXCLUSIVELY_SET_ERROR, dmlEx.getDMLMessage(0));

			dmlEx = null;
			jEntryLine.Account__c = testData.accounts[0].Id;
			jEntryLine.Contact__c = testData.contacts[0].Id;
			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(JournalEntryLineActions.ACCOUNT_NOT_EXCLUSIVELY_SET_ERROR, dmlEx.getDMLMessage(0));
		}
	}

	@IsTest
	public static void testValidatePayeeSetCorrectWhenAP() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
				?.GL_Account__c;
			jEntryLine.Account__c = null;
			jEntryLine.Contact__c = null;
			jEntryLine.Employee__c = null;

			DMLException dmlEx;
			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(JournalEntryLineActions.PAYEE_NOT_EXCLUSIVELY_SET_ERROR, dmlEx.getDMLMessage(0));

			dmlEx = null;
			jEntryLine.Account__c = testData.accounts[0].Id;
			jEntryLine.Contact__c = testData.contacts[0].Id;
			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(JournalEntryLineActions.PAYEE_NOT_EXCLUSIVELY_SET_ERROR, dmlEx.getDMLMessage(0));
		}
	}

	@IsTest
	public static void testValidatePayeeSetCorrectWhenNotAPorAR() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			List<Journal_Entry_Line__c> testJournalEntryLines = new List<Journal_Entry_Line__c>();
			testJournalEntryLines.add(
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 100,
					GL_Account__c = testData.glAccounts[25].Id,
					Units__c = 10,
					Reference__c = 'ref 1',
					Account__c = null,
					Contact__c = null,
					Employee__c = null
				)
			);

			testJournalEntryLines.add(
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 100,
					GL_Account__c = testData.glAccounts[25].Id,
					Units__c = 10,
					Reference__c = 'ref 2',
					Account__c = testData.accounts[0].Id,
					Contact__c = null,
					Employee__c = null
				)
			);

			testJournalEntryLines.add(
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 100,
					GL_Account__c = testData.glAccounts[25].Id,
					Units__c = 10,
					Reference__c = 'ref 3',
					Account__c = testData.accounts[0].Id,
					Contact__c = testData.contacts[0].Id,
					Employee__c = testData.users[0].Id
				)
			);

			DMLException dmlEx;
			try {
				insert testJournalEntryLines;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(null, dmlEx);
		}
	}

	@IsTest
	public static void testAssociateWithCashFlowCategoryOnUpdate() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			testData.createCashFlowCategories(true);

			Test.startTest();

			Journal_Entry__c testJE = new Journal_Entry__c(
				Name = 'Test JE',
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Journal_Date__c = testData.acctPeriods[0].Start_Date__c.addDays(10),
				Status__c = 'Approved'
			);

			insert testJE;

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testJE.Id,
				Credit__c = 100,
				GL_Account__c = testData.glAccounts[17].Id,
				Units__c = 10,
				Reference__c = 'the reference XXX'
			);

			insert jEntryLine;

			System.assertEquals(
				null,
				[
					SELECT Id, Cash_Flow_Category__c
					FROM Journal_Entry_Line__c
					WHERE Id = :jEntryLine.Id
				]
				.Cash_Flow_Category__c
			);

			testData.glAccounts[16].Bank__c = true;
			update testData.glAccounts[16];

			jEntryLine.GL_Account__c = testData.glAccounts[16].Id;
			update jEntryLine;

			Test.stopTest();
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Id defaultJELCategory = defaultsBySpecDevNames.get(
					GLAccountDefaultsHandler.DEFAULT_JOURNAL_ENTRY_LINE_CATEGORY
				)
				?.GL_Account__c;
			System.assertEquals(
				defaultJELCategory,
				[
					SELECT Id, Cash_Flow_Category__c
					FROM Journal_Entry_Line__c
					WHERE Id = :jEntryLine.Id
				]
				.Cash_Flow_Category__c
			);
		}

	}

	@IsTest
	public static void testDebitAndCreditBothPopulatedInsertError() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Debit__c = 1;
			jEntryLine.Credit__c = 2;

			DMLException dmlEx;

			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.BOTH_CREDIT_AND_DEBIT_ERROR, new List<String>{ '' }),
				dmlEx.getDMLMessage(0)
			);
		}

	}

	@IsTest
	public static void testDebitAndCreditBothPopulatedUpdateError() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Debit__c = 1;
			jEntryLine.Credit__c = null;
			insert jEntryLine;

			jEntryLine.Credit__c = 2;

			DMLException dmlEx;

			try {
				update jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.BOTH_CREDIT_AND_DEBIT_ERROR, new List<String>{ '' }),
				dmlEx.getDMLMessage(0)
			);
		}

	}

	@IsTest
	public static void testDebitAndCreditNeitherPopulatedInsertError() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Debit__c = null;
			jEntryLine.Credit__c = null;

			DMLException dmlEx;

			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.NEITHER_CREDIT_AND_DEBIT_ERROR, new List<String>{ '' }),
				dmlEx.getDMLMessage(0)
			);
		}

	}

	@IsTest
	public static void testDebitAndCreditNeitherPopulatedUpdateError() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Debit__c = 1;
			jEntryLine.Credit__c = null;

			insert jEntryLine;
			jEntryLine.Debit__c = null;

			DMLException dmlEx;

			try {
				update jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.NEITHER_CREDIT_AND_DEBIT_ERROR, new List<String>{ '' }),
				dmlEx.getDMLMessage(0)
			);
		}

	}

	@IsTest
	public static void testPopulateDateFieldInsertSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Date__c = null;
			insert jEntryLine;

			System.assertEquals(
				testData.journalEntries[0].Journal_Date__c,
				[
					SELECT Id, Date__c
					FROM Journal_Entry_Line__c
					WHERE Id = :jEntryLine.Id
				]
				.Date__c
			);
		}

	}

	@IsTest
	public static void testPopulateDateFieldUpdateSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntryLines[0].Date__c = null;
			update testData.journalEntryLines[0];

			System.assertEquals(
				testData.journalEntries[0].Journal_Date__c,
				[
					SELECT Id, Date__c
					FROM Journal_Entry_Line__c
					WHERE Id = :testData.journalEntryLines[0].Id
				]
				.Date__c
			);
		}

	}

	@IsTest
	public static void testPreventUpdateActionPostedNoChangeSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntries[0].Status__c = 'Approved';
			update testData.journalEntries[0];
			testData.journalEntryLines[0].Credit__c = 100.129;
			testData.journalEntryLines[1].Debit__c = 100.129;
			update testData.journalEntryLines;

			ApexPages.StandardController controller = new ApexPages.StandardController(
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
			);
			JournalEntryPost jep = new JournalEntryPost(controller);
			jep.post();

			System.assertEquals(
				'Posted',
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
				.Status__c
			);

			DMLException dmlEx;

			try {
				update testData.journalEntryLines[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(null, dmlEx);
		}

	}

	@IsTest
	public static void testPreventUpdateActionPostedNoChangeSetScaleSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntries[0].Status__c = 'Approved';
			update testData.journalEntries[0];
			testData.journalEntryLines[0].Credit__c = 100.129;
			testData.journalEntryLines[1].Debit__c = 100.129;
			update testData.journalEntryLines;

			ApexPages.StandardController controller = new ApexPages.StandardController(
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
			);

			JournalEntryPost jep = new JournalEntryPost(controller);
			jep.post();

			System.assertEquals(
				'Posted',
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
				.Status__c
			);

			DMLException dmlEx;

			// Test update no error since no fields changed.
			Journal_Entry_Line__c jel = [
				SELECT Id, Debit__c, Credit__c
				FROM Journal_Entry_Line__c
				WHERE Id = :testData.journalEntryLines[0].Id
				LIMIT 1
			];

			try {
				jel.Credit__c = 100.13;
				update jel;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(null, dmlEx);
		}

	}

	@IsTest
	public static void testPreventDeleteLineActionPosted() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntries[0].Status__c = 'Approved';
			update testData.journalEntries[0];

			ApexPages.StandardController controller = new ApexPages.StandardController(
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
			);

			JournalEntryPost jep = new JournalEntryPost(controller);
			jep.post();

			System.assertEquals(
				'Posted',
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
				.Status__c
			);

			DMLException dmlEx;
			try {
				delete testData.journalEntryLines;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
		}

	}

	@IsTest
	public static void testSetFieldValuesSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createBankReconciliations()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Date__c = null;
			jEntryLine.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
			jEntryLine.Cleared_Date__c = System.today();
			JournalEntryLineActions.isPreventUpdateOverride = true;
			insert jEntryLine;
			JournalEntryLineActions.isPreventUpdateOverride = false;

			System.assertEquals(
				null,
				[
					SELECT Id, Bank_Reconciliation__c
					FROM Journal_Entry_Line__c
					WHERE Id = :jEntryLine.Id
				]
				.Bank_Reconciliation__c
			);

			System.assertEquals(
				null,
				[
					SELECT Id, Cleared_Date__c
					FROM Journal_Entry_Line__c
					WHERE Id = :jEntryLine.Id
				]
				.Cleared_Date__c
			);
		}

	}

	@IsTest
	public static void testJournalEntryPreventUpdateBankReconciliationFieldSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createBankReconciliations()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntryLines[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

			DMLException dmlEx;
			try {
				update testData.journalEntryLines[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
		}

	}

	@IsTest
	public static void testJournalEntryPreventUpdateBankDepositFieldSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createBankDeposits()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntryLines[0].Bank_Deposit__c = testData.bankDeposits[0].Id;

			DMLException dmlEx;
			try {
				update testData.journalEntryLines[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(System.StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION, dmlEx.getDmlType(0));
		}

	}

	@IsTest
	public static void testPreventDeleteLineAction() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createBankDeposits()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.journalEntries[0].Status__c = 'Approved';
			update testData.journalEntries;

			PostResult result = JournalEntryPostService.postJournalEntries(
				new List<Journal_Entry__c>{ testData.journalEntries[0] }
			)[0];

			System.assertEquals(true, result.isSuccess);

			DMLException dmlEx;
			try {
				delete testData.journalEntryLines;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDmlMessage(0));
		}

	}

	@IsTest
	public static void testPopulateDefaultGlavsFromAccount() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createAccountingVariables()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Account testAccount = new Account(
				Name = 'Test Account With GLAVs',
				Accounting_Active__c = true,
				Accounting_Type__c = 'Customer and Vendor',
				GL_Account_Variable_1__c = testData.accountingVariables1[0].Id,
				GL_Account_Variable_2__c = testData.accountingVariables2[0].Id,
				GL_Account_Variable_3__c = testData.accountingVariables3[0].Id,
				GL_Account_Variable_4__c = testData.accountingVariables4[0].Id
			);

			insert testAccount;

			Journal_Entry__c testJE = new Journal_Entry__c(
				Name = 'The New JE',
				Journal_Date__c = System.today(),
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Status__c = 'Approved'
			);

			insert testJE;

			List<Journal_Entry_Line__c> testJournalEntryLines = new List<Journal_Entry_Line__c>{
				new Journal_Entry_Line__c(
					Journal_Entry__c = testJE.Id,
					Credit__c = 100,
					Account__c = testAccount.Id, //GLAVs source
					GL_Account__c = testData.glAccounts[0].Id
				),
				new Journal_Entry_Line__c(
					Journal_Entry__c = testJE.Id,
					Debit__c = 100,
					Account__c = testAccount.Id, //GLAVs from this Account will be ignored cause GLAVs will be set on JE line level
					GL_Account__c = testData.glAccounts[0].Id,
					GL_Account_Variable_1__c = testData.accountingVariables1[1].Id,
					GL_Account_Variable_2__c = testData.accountingVariables2[1].Id,
					GL_Account_Variable_3__c = testData.accountingVariables3[1].Id,
					GL_Account_Variable_4__c = testData.accountingVariables4[1].Id
				)
			};

			insert testJournalEntryLines;

			//Checking results
			//First JE line with GLAVs from the related Account
			List<Journal_Entry_Line__c> jeLines1 = [
				SELECT
					Id,
					GL_Account_Variable_1__c,
					GL_Account_Variable_2__c,
					GL_Account_Variable_3__c,
					GL_Account_Variable_4__c
				FROM Journal_Entry_Line__c
				WHERE Journal_Entry__c = :testJE.Id AND Account__c = :testAccount.Id AND Credit__c != NULL
				LIMIT 1
			];

			System.assertEquals(1, jeLines1.size());
			System.assertEquals(testData.accountingVariables1[0].Id, jeLines1[0].GL_Account_Variable_1__c);
			System.assertEquals(testData.accountingVariables2[0].Id, jeLines1[0].GL_Account_Variable_2__c);
			System.assertEquals(testData.accountingVariables3[0].Id, jeLines1[0].GL_Account_Variable_3__c);
			System.assertEquals(testData.accountingVariables4[0].Id, jeLines1[0].GL_Account_Variable_4__c);

			//Second line with GLAVs set by User directly
			List<Journal_Entry_Line__c> jeLines2 = [
				SELECT
					Id,
					GL_Account_Variable_1__c,
					GL_Account_Variable_2__c,
					GL_Account_Variable_3__c,
					GL_Account_Variable_4__c
				FROM Journal_Entry_Line__c
				WHERE Journal_Entry__c = :testJE.Id AND Account__c = :testAccount.Id AND Debit__c != NULL
				LIMIT 1
			];

			System.assertEquals(1, jeLines1.size());
			System.assertEquals(testData.accountingVariables1[1].Id, jeLines2[0].GL_Account_Variable_1__c);
			System.assertEquals(testData.accountingVariables2[1].Id, jeLines2[0].GL_Account_Variable_2__c);
			System.assertEquals(testData.accountingVariables3[1].Id, jeLines2[0].GL_Account_Variable_3__c);
			System.assertEquals(testData.accountingVariables4[1].Id, jeLines2[0].GL_Account_Variable_4__c);
		}

	}

	@IsTest
	public static void testPopulateDefaultGlavsFromProduct() {
		TestDataSuite testData = TestDataSuite.getInstance().createAccountingVariables().createProducts();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Product2 testProduct = testData.products[0];
			testProduct.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
			testProduct.GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
			testProduct.GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
			testProduct.GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;

			update testProduct;

			Journal_Entry__c testJE = new Journal_Entry__c(
				Name = 'The New JE',
				Journal_Date__c = System.today(),
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Status__c = 'Approved'
			);

			insert testJE;

			List<Journal_Entry_Line__c> testJournalEntryLines = new List<Journal_Entry_Line__c>{
				new Journal_Entry_Line__c(
					Journal_Entry__c = testJE.Id,
					Credit__c = 100,
					Product__c = testProduct.Id, //GLAVs source
					GL_Account__c = testData.glAccounts[0].Id
				),
				new Journal_Entry_Line__c(
					Journal_Entry__c = testJE.Id,
					Debit__c = 100,
					Product__c = testProduct.Id, //GLAVs from this Product will be ignored cause GLAVs will be set on JE line level
					GL_Account__c = testData.glAccounts[0].Id,
					GL_Account_Variable_1__c = testData.accountingVariables1[1].Id,
					GL_Account_Variable_2__c = testData.accountingVariables2[1].Id,
					GL_Account_Variable_3__c = testData.accountingVariables3[1].Id,
					GL_Account_Variable_4__c = testData.accountingVariables4[1].Id
				)
			};

			insert testJournalEntryLines;

			//Checking results
			//First JE line with GLAVs from the related Product
			List<Journal_Entry_Line__c> jeLines1 = [
				SELECT
					Id,
					GL_Account_Variable_1__c,
					GL_Account_Variable_2__c,
					GL_Account_Variable_3__c,
					GL_Account_Variable_4__c
				FROM Journal_Entry_Line__c
				WHERE Journal_Entry__c = :testJE.Id AND Product__c = :testProduct.Id AND Credit__c != NULL
				LIMIT 1
			];

			System.assertEquals(1, jeLines1.size());
			System.assertEquals(testData.accountingVariables1[0].Id, jeLines1[0].GL_Account_Variable_1__c);
			System.assertEquals(testData.accountingVariables2[0].Id, jeLines1[0].GL_Account_Variable_2__c);
			System.assertEquals(testData.accountingVariables3[0].Id, jeLines1[0].GL_Account_Variable_3__c);
			System.assertEquals(testData.accountingVariables4[0].Id, jeLines1[0].GL_Account_Variable_4__c);

			//Second line with GLAVs set by User directly
			List<Journal_Entry_Line__c> jeLines2 = [
				SELECT
					Id,
					GL_Account_Variable_1__c,
					GL_Account_Variable_2__c,
					GL_Account_Variable_3__c,
					GL_Account_Variable_4__c
				FROM Journal_Entry_Line__c
				WHERE Journal_Entry__c = :testJE.Id AND Product__c = :testProduct.Id AND Debit__c != NULL
				LIMIT 1
			];

			System.assertEquals(1, jeLines1.size());
			System.assertEquals(testData.accountingVariables1[1].Id, jeLines2[0].GL_Account_Variable_1__c);
			System.assertEquals(testData.accountingVariables2[1].Id, jeLines2[0].GL_Account_Variable_2__c);
			System.assertEquals(testData.accountingVariables3[1].Id, jeLines2[0].GL_Account_Variable_3__c);
			System.assertEquals(testData.accountingVariables4[1].Id, jeLines2[0].GL_Account_Variable_4__c);
		}

	}

	@IsTest
	public static void testPreventBankDepositFieldValueCloning() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankDeposits()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			JournalEntryLineActions.isPreventUpdateOverride = true;
			testData.journalEntryLines[0].Bank_Deposit__c = testData.bankDeposits[0].Id;
			JournalEntryLineActions.isPreventUpdateOverride = false;

			insert testData.journalEntryLines[0].clone(false, true);

			Journal_Entry_Line__c newLine = [
				SELECT Id, Bank_Deposit__c
				FROM Journal_Entry_Line__c
				WHERE Id = :testData.journalEntryLines[0].Id
				LIMIT 1
			];

			System.assertEquals(null, newLine.Bank_Deposit__c);
		}

	}

	@IsTest
	public static void testWrongTimeCardVariablesInsertError() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createAccountingVariables()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0].clone(false, true);
			jEntryLine.Time_Card_Variable_1__c = testData.accountingVariables1[0].Id;

			DMLException dmlEx;

			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.WRONG_TIME_CARD_VARIABLES_ERROR, new List<String>{ '1' }),
				dmlEx.getDMLMessage(0)
			);

			jEntryLine.Time_Card_Variable_1__c = null;
			jEntryLine.Time_Card_Variable_2__c = testData.accountingVariables1[0].Id;

			try {
				insert jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.WRONG_TIME_CARD_VARIABLES_ERROR, new List<String>{ '2' }),
				dmlEx.getDMLMessage(0)
			);
		}
	}

	@IsTest
	public static void testWrongTimeCardVariablesUpdateError() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createAccountingVariables()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Journal_Entry_Line__c jEntryLine = testData.journalEntryLines[0];
			jEntryLine.Time_Card_Variable_1__c = testData.accountingVariables1[0].Id;

			DMLException dmlEx;

			try {
				update jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.WRONG_TIME_CARD_VARIABLES_ERROR, new List<String>{ '1' }),
				dmlEx.getDMLMessage(0)
			);

			jEntryLine.Time_Card_Variable_1__c = null;
			jEntryLine.Time_Card_Variable_2__c = testData.accountingVariables1[0].Id;

			try {
				update jEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(JournalEntryLineActions.WRONG_TIME_CARD_VARIABLES_ERROR, new List<String>{ '2' }),
				dmlEx.getDMLMessage(0)
			);
		}
	}

	@IsTest
	public static void testJournalEntryLineNoNullPointerExceptionInsert() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			DMLException dmlEx;
			try {
				Journal_Entry_Line__c jel = new Journal_Entry_Line__c();
				insert jel;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
		}
	}

	@IsTest
	public static void testJournalEntryLineNoNullPointerExceptionInsert_MC() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance()
				.enableMultiCurrency() //will throw an exception in case of non-MC org
				.createProjects()
				.createProjectTasks()
				.createJournalEntries();

			System.runAs(testData.users.get(1)) {
				DMLException dmlEx;
				try {
					Journal_Entry_Line__c jel = new Journal_Entry_Line__c();
					insert jel;
				} catch (DMLException ex) {
					dmlEx = ex;
				}
				System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
			}
		} catch (TestDataSuite.TestDataSuiteException ex) {
			//just skip this test if it is non-MC org
		}
	}

	@IsTest
	public static void testNormalizeNumericAndCurrencyFieldsInsert() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			List<Journal_Entry_Line__c> testJournalEntryLines = new List<Journal_Entry_Line__c>{
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 20.989342348934,
					GL_Account__c = testData.glAccounts[0].Id,
					Units__c = 10.236746723674344
				),
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Debit__c = 23.423423545452423,
					GL_Account__c = testData.glAccounts[0].Id,
					Units__c = 3.4237468273582872853
				)
			};

			insert testJournalEntryLines;

			Journal_Entry_Line__c newJELCredit = [
				SELECT Id, Journal_Entry__c, Debit__c, Credit__c, Units__c
				FROM Journal_Entry_Line__c
				WHERE
					Journal_Entry__c = :testData.journalEntries[0].Id
					AND Credit__c != NULL
					AND Id IN :testJournalEntryLines
			];

			Journal_Entry_Line__c newJELDebit = [
				SELECT Id, Journal_Entry__c, Debit__c, Credit__c, Units__c
				FROM Journal_Entry_Line__c
				WHERE
					Journal_Entry__c = :testData.journalEntries[0].Id
					AND Debit__c != NULL
					AND Id IN :testJournalEntryLines
			];

			System.assertEquals(20.99, newJELCredit.Credit__c);
			System.assertEquals(10.236747, newJELCredit.Units__c);
			System.assertEquals(23.42, newJELDebit.Debit__c);
			System.assertEquals(3.423747, newJELDebit.Units__c);
		}

	}

	@IsTest
	public static void testNormalizeNumericAndCurrencyFieldsUpdate() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries();

		System.runAs(testData.users.get(1)) {
			testData.journalEntryLines[0].Credit__c = 20.989342348934;
			testData.journalEntryLines[0].Units__c = 10.236746723674344;
			testData.journalEntryLines[1].Debit__c = 23.423423545452423;
			testData.journalEntryLines[1].Units__c = 3.4237468273582872853;

			update testData.journalEntryLines[0];
			update testData.journalEntryLines[1];

			Journal_Entry_Line__c newJELCredit = [
				SELECT Id, Journal_Entry__c, Debit__c, Credit__c, Units__c
				FROM Journal_Entry_Line__c
				WHERE
					Journal_Entry__c = :testData.journalEntries[0].Id
					AND Credit__c != NULL
					AND Id = :testData.journalEntryLines[0].Id
			];

			Journal_Entry_Line__c newJELDebit = [
				SELECT Id, Journal_Entry__c, Debit__c, Credit__c, Units__c
				FROM Journal_Entry_Line__c
				WHERE
					Journal_Entry__c = :testData.journalEntries[0].Id
					AND Debit__c != NULL
					AND Id = :testData.journalEntryLines[1].Id
			];

			System.assertEquals(20.99, newJELCredit.Credit__c);
			System.assertEquals(10.236747, newJELCredit.Units__c);
			System.assertEquals(23.42, newJELDebit.Debit__c);
			System.assertEquals(3.423747, newJELDebit.Units__c);
		}

	}

	@isTest
	public static void testSetCurrencyFromParent() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance()
				.enableMultiCurrency() //will throw an exception in case of non-MC org
				.createProjects()
				.createProjectTasks()
				.createJournalEntries();

			System.runAs(testData.users.get(1)) {
				String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(newCurrency)) {
					return;
				}
				String testJEId = testData.journalEntries[0].Id;
				String parentCurrency = (String) Database.query(
						'SELECT CurrencyIsoCode FROM ' +
							GlobalVariables.PACKAGE_QUALIFIER +
							'Journal_Entry__c WHERE Id = :testJEId'
					)[0]
					.get('CurrencyIsoCode');
				System.assertNotEquals(newCurrency, parentCurrency);

				Journal_Entry_Line__c jeLine = new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 20,
					GL_Account__c = testData.glAccounts[0].Id,
					Units__c = 10
				);
				jeLine.put('CurrencyIsoCode', newCurrency);

				insert jeLine;

				String lineId = jeLine.Id;
				String lineCurrencyInsert = (String) Database.query(
						'SELECT CurrencyIsoCode FROM ' +
							GlobalVariables.PACKAGE_QUALIFIER +
							'Journal_Entry_Line__c WHERE Id = :lineId'
					)[0]
					.get('CurrencyIsoCode');

				System.assertEquals(parentCurrency, lineCurrencyInsert);

				jeLine.put('CurrencyIsoCode', newCurrency);

				update jeLine;

				String lineCurrencyUpdate = (String) Database.query(
						'SELECT CurrencyIsoCode FROM ' +
							GlobalVariables.PACKAGE_QUALIFIER +
							'Journal_Entry_Line__c WHERE Id = :lineId'
					)[0]
					.get('CurrencyIsoCode');

				System.assertEquals(parentCurrency, lineCurrencyUpdate);
			}

		} catch (TestDataSuite.TestDataSuiteException ex) {
			//just skip this test if it is non-MC org
		}
	}

	@isTest
	public static void validateGLBankAccount() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();

			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[1].Id;
			update testData.bankDisbursements[0];

			List<Journal_Entry_Line__c> listOfJELs = new List<Journal_Entry_Line__c>();

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Credit__c = 200,
				GL_Account__c = testData.glAccounts[25].Id,
				Reference__c = 'ref 3',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine);

			Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Debit__c = 200,
				GL_Account__c = testData.glAccounts[25].Id,
				Reference__c = 'ref 2',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine1);
			insert listOfJELs;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			Journal_Entry_Line__c jelRec = [
				SELECT ID
				FROM Journal_Entry_Line__c
				WHERE Id = :jEntryLine.Id
			];
			jelRec.Bank_Disbursement__c = testData.bankDisbursements[0].Id;

			DmlException dmlEx;
			try {
				update jelRec;
			} catch (DmlException ex) {
				dmlEx = ex;
			}
			System.assertEquals(
				Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_ACCOUNT_DOESNT_MATCH_ON_BD,
				dmlEx.getDMLMessage(0)
			);

			Test.stopTest();
		}
	}

	@isTest
	public static void validateDisbursementDate() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			List<Journal_Entry_Line__c> listOfJELs = new List<Journal_Entry_Line__c>();

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Credit__c = 200,
				GL_Account__c = testData.glAccounts[25].Id,
				Reference__c = 'ref 3',
				Date__c = System.Today()
			);
			listOfJELs.add(jEntryLine);

			Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Debit__c = 200,
				GL_Account__c = testData.glAccounts[25].Id,
				Reference__c = 'ref 2',
				Date__c = System.Today()
			);
			listOfJELs.add(jEntryLine1);
			insert listOfJELs;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			Journal_Entry_Line__c jelRec = [
				SELECT ID
				FROM Journal_Entry_Line__c
				WHERE Id = :jEntryLine.Id
			];

			DmlException dmlEx;
			try {
				jelRec.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
				update jelRec;
			} catch (DmlException ex) {
				dmlEx = ex;
			}
			System.assertEquals(
				Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_DATE_EXCEEDS_DISBURSEMENT_DATE_ON_BD,
				dmlEx.getDMLMessage(0)
			);
			Test.stopTest();
		}
	}

	@isTest
	public static void validateCurrencyFieldIfBankDisAssociated() {
		try {
			FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
			TestDataSuite testData = TestDataSuite.getInstance()
				.enableMultiCurrency()
				.createProjects()
				.createProjectTasks()
				.createJournalEntries()
				.createBankDisbursements();

			System.runAs(testData.users[1]) {
				Test.startTest();

				String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(theNewCurrencyIsoCode)) {
					return;
				}

				testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
				testData.bankDisbursements[0].put('CurrencyIsoCode', 'EUR');
				update testData.bankDisbursements[0];

				List<Journal_Entry_Line__c> listOfJELs = new List<Journal_Entry_Line__c>();

				Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 200,
					GL_Account__c = testData.glAccounts[25].Id,
					Reference__c = 'ref 3',
					Date__c = System.Today()
				);

				jEntryLine.put('CurrencyIsoCode', 'USD');
				listOfJELs.add(jEntryLine);

				Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Debit__c = 200,
					GL_Account__c = testData.glAccounts[25].Id,
					Reference__c = 'ref 2',
					Date__c = testData.acctPeriods[1].Start_Date__c
				);
				listOfJELs.add(jEntryLine1);
				insert listOfJELs;

				AbstractPostHandler postHandler = new JournalEntryPostHandler();
				List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

				Journal_Entry_Line__c jelRec = [
					SELECT ID
					FROM Journal_Entry_Line__c
					WHERE Id = :jEntryLine.Id
				];

				DmlException dmlEx;
				try {
					jelRec.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
					update jelRec;
				} catch (DmlException ex) {
					dmlEx = ex;
					Assert.isNotNull(ex);
					Assert.isTrue(ex.getMessage().contains(Label.ERR_JEL_CURRENCY_MISMATCH_BANK_DISB));
				}

				Test.stopTest();
			}
		} catch (TestDataSuite.TestDataSuiteException ex) {
			ex = ex;
		}
	}

	@isTest
	public static void validateBankDisbFieldForClearedBankRecOnJEL() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements()
			.createBankReconciliations();

		System.runAs(testData.users[1]) {
			Test.startTest();
			TriggerObserver.getInstance()
				.unlockFields(new Set<Schema.SObjectField>{ Journal_Entry_Line__c.Bank_Reconciliation__c });

			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			List<Journal_Entry_Line__c> listOfJELs = new List<Journal_Entry_Line__c>();

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Credit__c = 200,
				GL_Account__c = testData.glAccounts[0].Id,
				Reference__c = 'ref 3',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine);

			Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Debit__c = 200,
				GL_Account__c = testData.glAccounts[0].Id,
				Reference__c = 'ref 2',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine1);
			insert listOfJELs;

			jEntryLine.Bank_Reconciliation__c = testData.bankReconciliations[1].Id;
			update jEntryLine;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			Journal_Entry_Line__c jelRec = [
				SELECT ID
				FROM Journal_Entry_Line__c
				WHERE Id = :jEntryLine.Id
			];

			DmlException dmlEx;
			try {
				jelRec.Bank_Disbursement__c = testData.bankDisbursements[1].Id;
				update jelRec;
			} catch (DmlException ex) {
				dmlEx = ex;
			}
			Bank_Reconciliation2__c bankReconciliationRec = [
				SELECT Id, Name
				FROM Bank_Reconciliation2__c
				WHERE Id = :testData.bankReconciliations[1].Id
			];
			System.assertEquals(
				String.format(
					Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED,
					new List<String>{
						Label.COMMON_JOURNAL_ENTRY_LINE,
						bankReconciliationRec.Name,
						Label.COMMON_JOURNAL_ENTRY_LINE
					}
				),
				dmlEx.getDMLMessage(0)
			);
			Test.stopTest();
		}
	}

	@isTest
	public static void validateBankDisbFieldIfClearedBankRecOnBankDisb() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements()
			.createBankReconciliations();

		System.runAs(testData.users[1]) {
			Test.startTest();

			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			testData.bankDisbursements[0].Bank_Reconciliation__c = testData.bankReconciliations[1].Id;
			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Bank_Disbursement__c.Bank_Reconciliation__c,
						Bank_Disbursement__c.Bank_Reconciliation_Date__c
					}
				);
			update testData.bankDisbursements[0];
			List<Journal_Entry_Line__c> listOfJELs = new List<Journal_Entry_Line__c>();

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Credit__c = 200,
				GL_Account__c = testData.glAccounts[0].Id,
				Reference__c = 'ref 3',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine);

			Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Debit__c = 200,
				GL_Account__c = testData.glAccounts[0].Id,
				Reference__c = 'ref 2',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine1);
			insert listOfJELs;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			Journal_Entry_Line__c jelRec = [
				SELECT ID
				FROM Journal_Entry_Line__c
				WHERE Id = :jEntryLine.Id
			];

			DmlException dmlEx;
			try {
				jelRec.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
				update jelRec;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			Bank_Reconciliation2__c bankReconciliationRec = [
				SELECT Id, Name
				FROM Bank_Reconciliation2__c
				WHERE Id = :testData.bankReconciliations[1].Id
			];
			System.assertEquals(
				String.format(
					Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_BANK_RECONCILIATION_CLEARED,
					new List<String>{
						Label.COMMON_BANK_DISBURSEMENT,
						bankReconciliationRec.Name,
						Label.COMMON_BANK_DISBURSEMENT
					}
				),
				dmlEx.getDMLMessage(0)
			);
			Test.stopTest();
		}
	}

	@isTest
	public static void testCalcAmountAndLedgerAmountOnInsertCD() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			List<Journal_Entry_Line__c> listOfJELs = new List<Journal_Entry_Line__c>();

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Credit__c = 200,
				GL_Account__c = testData.glAccounts[0].Id,
				Reference__c = 'ref 3',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine);

			Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Debit__c = 200,
				GL_Account__c = testData.glAccounts[0].Id,
				Reference__c = 'ref 2',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELs.add(jEntryLine1);
			insert listOfJELs;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			jEntryLine.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update jEntryLine;

			Bank_Disbursement__c bankDis = [
				SELECT Id, Amount__c, Ledger_Amount__c
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];
			System.assertEquals(200, bankDis.Amount__c);
			System.assertEquals(200, bankDis.Ledger_Amount__c);

			Test.stopTest();
		}
	}

	@isTest
	public static void testCalcAmountAndLedgerAmountOnDeleteCD() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			List<Journal_Entry_Line__c> listOfJELToInsert = new List<Journal_Entry_Line__c>();
			List<Journal_Entry_Line__c> listOfJELToUpdate = new List<Journal_Entry_Line__c>();
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[25].Id;
			update testData.bankDisbursements[0];

			Journal_Entry_Line__c jEntryLine = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Credit__c = 200,
				GL_Account__c = testData.glAccounts[25].Id,
				Reference__c = 'ref 3',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELToInsert.add(jEntryLine);

			Journal_Entry_Line__c jEntryLine1 = new Journal_Entry_Line__c(
				Journal_Entry__c = testData.journalEntries[0].Id,
				Debit__c = 200,
				GL_Account__c = testData.glAccounts[25].Id,
				Reference__c = 'ref 2',
				Date__c = testData.acctPeriods[1].Start_Date__c
			);
			listOfJELToInsert.add(jEntryLine1);
			insert listOfJELToInsert;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			jEntryLine.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update jEntryLine;

			List<Journal_Entry_Line__c> listOfjels = [
				SELECT Id
				FROM JOURNAL_ENTRY_LINE__C
				WHERE BANK_DISBURSEMENT__C = :testData.bankDisbursements[0].Id
			];
			System.assertEquals(1, listOfjels.size());

			Bank_Disbursement__c bankDis = [
				SELECT Id, Amount__c, Ledger_Amount__c
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];
			System.assertEquals(200, bankDis.Amount__c);
			System.assertEquals(200, bankDis.Ledger_Amount__c);

			postHandler.dispatcher.clearResultsMap();
			List<PostResult> results1 = postHandler.unpost(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			System.assertEquals(true, results1[0].isSuccess);
			System.assertNotEquals(
				AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
				[
					SELECT Status__c
					FROM Journal_Entry__c
					WHERE Id = :testData.journalEntries[0].Id
				]
				.Status__c
			);

			Journal_Entry_Line__c jeL = [
				SELECT Id
				FROM Journal_Entry_Line__c
				WHERE Id = :jEntryLine.Id
			];

			delete jeL;

			Bank_Disbursement__c updatedbankDis = [
				SELECT Id, Amount__c, Ledger_Amount__c
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];
			System.assertEquals(0, updatedbankDis.Amount__c);
			System.assertEquals(0, updatedbankDis.Ledger_Amount__c);

			Test.stopTest();
		}
	}

	@isTest
	public static void testValidateBankDepositNdBankDisbAssociation() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankDeposits()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			List<Journal_Entry_Line__c> journalEntryLines = new List<Journal_Entry_Line__c>();

			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[25].Id;
			update testData.bankDisbursements[0];
			journalEntryLines.add(
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					Credit__c = 200,
					GL_Account__c = testData.glAccounts[25].Id,
					Reference__c = 'ref 3',
					Date__c = testData.acctPeriods[1].Start_Date__c
				)
			);
			journalEntryLines.add(
				new Journal_Entry_Line__c(
					Journal_Entry__c = testData.journalEntries[0].Id,
					debit__c = 200,
					GL_Account__c = testData.glAccounts[25].Id,
					Reference__c = 'ref 3',
					Date__c = testData.acctPeriods[1].Start_Date__c
				)
			);
			if (!journalEntryLines.isEmpty()) {
				insert journalEntryLines;
			}

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			List<PostResult> results = postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			journalEntryLines[0].Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update journalEntryLines[0];
			journalEntryLines[0].Bank_Deposit__c = testData.bankDeposits[0].Id;

			DmlException dmlEx;
			try {
				update journalEntryLines[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			Bank_Disbursement__c bankDisbursement = [
				SELECT Id, Name
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];
			System.assertEquals(
				String.format(
					JournalEntryLineActions.JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB,
					new List<String>{ 'Bank Deposit', ('Bank Disbursement' + '{' + bankDisbursement.Name + '}') }
				),
				dmlEx.getDMLMessage(0)
			);

			journalEntryLines[1].Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			journalEntryLines[1].Bank_Deposit__c = testData.bankDeposits[0].Id;

			try {
				update journalEntryLines[1];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				JournalEntryLineActions.JEL_CANT_BE_ASSOCIATED_TO_BD_AND_BDB_BOTH,
				dmlEx.getDMLMessage(0)
			);
			Test.stopTest();
		}
	}

	@isTest
	public static void testPreventBDBAssociationIfDifferentGLV() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createAccountingVariables()
			.createProjects()
			.createProjectTasks()
			.createJournalEntries()
			.createBankDisbursements();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.bankDisbursements[0].GL_Account_Variable_1__c = testData.accountingVariables1[1].Id;
			testData.bankDisbursements[0].Disbursement_Date__c = System.today();
			update testData.bankDisbursements[0];

			Journal_Entry_Line__c journalEntryLine = testData.journalEntryLines[0];
			journalEntryLine.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;

			update journalEntryLine;

			AbstractPostHandler postHandler = new JournalEntryPostHandler();
			postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });

			journalEntryLine.Bank_Disbursement__c = testData.bankDisbursements[0].Id;

			DmlException dmlEx;
			try {
				update journalEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			Bank_Disbursement__c bankDisbursement = [
				SELECT Id, Name
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];

			System.assertEquals(
				String.format(
					JournalEntryLineActions.JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);

			postHandler.dispatcher.clearResultsMap();
			postHandler.unpost(new List<Journal_Entry__c>{ testData.journalEntries[0] });
			testData.bankDisbursements[0].GL_Account_Variable_2__c = testData.accountingVariables1[1].Id;
			update testData.bankDisbursements[0];

			postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });
			journalEntryLine.GL_Account_Variable_1__c = null;
			journalEntryLine.GL_Account_Variable_2__c = testData.accountingVariables1[0].Id;

			try {
				update journalEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					JournalEntryLineActions.JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);

			postHandler.dispatcher.clearResultsMap();
			postHandler.unpost(new List<Journal_Entry__c>{ testData.journalEntries[0] });
			testData.bankDisbursements[0].GL_Account_Variable_3__c = testData.accountingVariables1[1].Id;
			update testData.bankDisbursements[0];

			postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });
			journalEntryLine.GL_Account_Variable_1__c = null;
			journalEntryLine.GL_Account_Variable_2__c = null;
			journalEntryLine.GL_Account_Variable_3__c = testData.accountingVariables1[0].Id;

			try {
				update journalEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					JournalEntryLineActions.JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);

			postHandler.dispatcher.clearResultsMap();
			postHandler.unpost(new List<Journal_Entry__c>{ testData.journalEntries[0] });
			testData.bankDisbursements[0].GL_Account_Variable_4__c = testData.accountingVariables1[1].Id;
			update testData.bankDisbursements[0];

			postHandler.post(new List<Journal_Entry__c>{ testData.journalEntries[0] });
			journalEntryLine.GL_Account_Variable_1__c = null;
			journalEntryLine.GL_Account_Variable_2__c = null;
			journalEntryLine.GL_Account_Variable_3__c = null;
			journalEntryLine.GL_Account_Variable_4__c = testData.accountingVariables1[0].Id;

			try {
				update journalEntryLine;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					JournalEntryLineActions.JEL_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);
		}
	}
}
