@IsTest
private class CashDisbursementActionsTest {
	@TestSetup
	private static void setupTestData() {
		TestDataSuite.getInstance(true);
	}

	@IsTest
	private static void testSetDefaultGLAVFromRelatedAccount() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.createAccountingVariables().createCashDisbursementBatches().createCashDisbursements();
			testData.accounts[0].GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
			testData.accounts[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
			testData.accounts[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
			testData.accounts[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
			update testData.accounts[0];

			Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
			testCD.Debit_GL_Account__c = null;
			insert testCD;

			System.assertEquals(
				testData.accounts[0].GL_Account_Variable_1__c,
				[SELECT GL_Account_Variable_1__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id]
				.GL_Account_Variable_1__c
			);

			System.assertEquals(
				testData.accounts[0].GL_Account_Variable_2__c,
				[SELECT GL_Account_Variable_2__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id]
				.GL_Account_Variable_2__c
			);

			System.assertEquals(
				testData.accounts[0].GL_Account_Variable_3__c,
				[SELECT GL_Account_Variable_3__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id]
				.GL_Account_Variable_3__c
			);

			System.assertEquals(
				testData.accounts[0].GL_Account_Variable_4__c,
				[SELECT GL_Account_Variable_4__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id]
				.GL_Account_Variable_4__c
			);

			Test.stopTest();
		}
	}

	@IsTest
	private static void testPopulatePayeeDataFromVendor() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.createCashDisbursementBatches().createCashDisbursements();
			Integer Year = Date.today().Year();

			Id formTypeId = [
				SELECT Id, Effective_Year__c
				FROM Form_Type__mdt
				WHERE Effective_Year__c <= :Year
				ORDER BY Effective_Year__c DESC
				LIMIT 1
			]
			.Id;
			Id formCategoryId = [SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;

			Account testAccount = new Account(
				Name = 'Test Account With Billing Address',
				Alternate_Payee_Name__c = 'TAWBA',
				BillingStreet = 'Some Street',
				BillingCity = 'Some City',
				BillingState = 'Some State',
				BillingPostalCode = '99666',
				BillingCountry = 'Some Country',
				X1099_Vendor__c = true,
				Default_Form_Category_Id__c = formCategoryId
			);
			insert testAccount;

			Accounting_Period__c acctPeriod = new Accounting_Period__c(
				Name = Year + '-01',
				Start_Date__c = Date.newInstance(Year, 1, 1),
				End_Date__c = Date.newInstance(Year, 12, 31),
				Status__c = AccountingPeriodActions.OPEN_STATUS
			);
			insert acctPeriod;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = testAccount.Id;
			cd.Disbursement_Date__c = acctPeriod.Start_Date__c;
			cd.Debit_GL_Account__c = null;
			insert cd;

			Cash_Disbursement__c theNewCD = [
				SELECT
					Id,
					Alternate_Payee_Name__c,
					Payee_Street__c,
					Payee_Street2__c,
					Payee_City__c,
					Payee_State__c,
					Payee_Postal_Code__c,
					Payee_Country__c,
					Payee_Country2__c,
					Payee_City_State_Zip__c,
					Form_Category_Id__c,
					Form_1099_Box__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];

			System.assertEquals(testAccount.Alternate_Payee_Name__c, theNewCD.Alternate_Payee_Name__c);
			System.assertEquals(testAccount.BillingStreet, theNewCD.Payee_Street2__c);
			System.assertEquals(testAccount.BillingStreet, theNewCD.Payee_Street__c);
			System.assertEquals(testAccount.BillingCity, theNewCD.Payee_City__c);
			System.assertEquals(testAccount.BillingState, theNewCD.Payee_State__c);
			System.assertEquals(testAccount.BillingPostalCode, theNewCD.Payee_Postal_Code__c);
			System.assertEquals(testAccount.BillingCountry, theNewCD.Payee_Country__c);
			System.assertEquals(testAccount.BillingCountry, theNewCD.Payee_Country2__c);
			System.assertEquals(
				testAccount.BillingCity + ' ' + testAccount.BillingState + ' ' + testAccount.BillingPostalCode,
				theNewCD.Payee_City_State_Zip__c
			);
			System.assertEquals(formCategoryId, theNewCD.Form_Category_Id__c);
			Test.stopTest();
		}

	}

	@IsTest
	private static void testPopulatePayeeDataBulk() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.createCashDisbursementBatches().createCashDisbursements();
			Integer Year = Date.today().Year();

			Id formTypeId = [
				SELECT Id, Effective_Year__c
				FROM Form_Type__mdt
				WHERE Effective_Year__c <= :Year
				ORDER BY Effective_Year__c DESC
				LIMIT 1
			]
			.Id;
			Id formCategoryId = [SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;
			Account testAccount = new Account(
				Name = 'Test Account With Billing Address',
				Alternate_Payee_Name__c = 'TAWBA',
				BillingStreet = 'Some Street',
				BillingCity = 'Some City',
				BillingState = 'Some State',
				BillingPostalCode = '99666',
				BillingCountry = 'Some Country',
				X1099_Vendor__c = true,
				Default_Form_Category_Id__c = formCategoryId
			);
			insert testAccount;

			Contact testContact = new Contact(
				FirstName = 'test',
				LastName = 'test2',
				MailingStreet = 'Some Street1',
				MailingCity = 'Some City1',
				MailingState = 'Some State1',
				MailingPostalCode = '996661',
				MailingCountry = 'Some Country1',
				X1099_Vendor__c = true,
				Default_Form_Category_Id__c = formCategoryId
			);
			insert testContact;

			Accounting_Period__c acctPeriod = new Accounting_Period__c(
				Name = Year + '-01',
				Start_Date__c = Date.newInstance(Year, 1, 1),
				End_Date__c = Date.newInstance(Year, 12, 31),
				Status__c = AccountingPeriodActions.OPEN_STATUS
			);
			insert acctPeriod;

			List<Cash_Disbursement__c> bulkCDs = new List<Cash_Disbursement__c>();
			for (Integer i = 0; i < 200; i++) {
				Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
				if (i > 100) {
					cd.Vendor__c = testAccount.Id;
					cd.Contact__c = null;
					cd.Disbursement_Date__c = acctPeriod.Start_Date__c;
				} else {
					cd.Vendor__c = null;
					cd.Contact__c = testContact.Id;
				}
				cd.Debit_GL_Account__c = null;
				bulkCDs.add(cd);
			}
			insert bulkCDs;

			for (Cash_Disbursement__c theNewCD : [
				SELECT Id, Vendor__c, Contact__c, Form_Category_Id__c, Form_1099_Box__c
				FROM Cash_Disbursement__c
				WHERE Id IN :bulkCDs
			]) {
				if (theNewCD.Vendor__c != null) {
					System.assertEquals(formCategoryId, theNewCD.Form_Category_Id__c);
				}
				if (theNewCD.Contact__c != null) {
					System.assertEquals(null, theNewCD.Form_Category_Id__c);
				}
			}
			Test.stopTest();
		}
	}

	@IsTest
	private static void testPopulatePayeeDataFromVendor1099NotValid() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			testData.createCashDisbursementBatches().createCashDisbursements();
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Integer Year = Date.today().Year();

			Id formTypeId = [
				SELECT Id, Effective_Year__c
				FROM Form_Type__mdt
				WHERE Effective_Year__c <= :Year
				ORDER BY Effective_Year__c DESC
				LIMIT 1
			]
			.Id;
			Id formCategoryId = [SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;

			Account testAccount = new Account(
				Name = 'Test Account With Billing Address',
				Alternate_Payee_Name__c = 'TAWBA',
				BillingStreet = 'Some Street',
				BillingCity = 'Some City',
				BillingState = 'Some State',
				BillingPostalCode = '99666',
				BillingCountry = 'Some Country',
				X1099_Vendor__c = true,
				Default_Form_Category_Id__c = formCategoryId
			);
			insert testAccount;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = testAccount.Id;
			cd.Debit_GL_Account__c = null;
			insert cd;

			Cash_Disbursement__c theNewCD = [
				SELECT
					Id,
					Alternate_Payee_Name__c,
					Payee_Street__c,
					Payee_Street2__c,
					Payee_City__c,
					Payee_State__c,
					Payee_Postal_Code__c,
					Payee_Country__c,
					Payee_Country2__c,
					Payee_City_State_Zip__c,
					Form_Category_Id__c,
					Form_1099_Box__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];

			System.assertEquals(testAccount.Alternate_Payee_Name__c, theNewCD.Alternate_Payee_Name__c);
			System.assertEquals(testAccount.BillingStreet, theNewCD.Payee_Street2__c);
			System.assertEquals(testAccount.BillingStreet, theNewCD.Payee_Street__c);
			System.assertEquals(testAccount.BillingCity, theNewCD.Payee_City__c);
			System.assertEquals(testAccount.BillingState, theNewCD.Payee_State__c);
			System.assertEquals(testAccount.BillingPostalCode, theNewCD.Payee_Postal_Code__c);
			System.assertEquals(testAccount.BillingCountry, theNewCD.Payee_Country__c);
			System.assertEquals(testAccount.BillingCountry, theNewCD.Payee_Country2__c);
			System.assertEquals(
				testAccount.BillingCity + ' ' + testAccount.BillingState + ' ' + testAccount.BillingPostalCode,
				theNewCD.Payee_City_State_Zip__c
			);
			System.assertEquals(null, theNewCD.Form_Category_Id__c);
			Test.stopTest();
		}

	}

	@IsTest
	private static void testPopulatePayeeDataFromContact() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		Accounting_Settings__c accountingSettings = testData.settings;
		accountingSettings.Cash_Disbursement_Source__c = 'Manual';
		update accountingSettings;

		System.runAs(testData.users.get(1)) {
			Integer Year = Date.today().Year();

			Id formTypeId = [
				SELECT Id, Effective_Year__c
				FROM Form_Type__mdt
				WHERE Effective_Year__c <= :Year
				ORDER BY Effective_Year__c DESC
				LIMIT 1
			]
			.Id;
			Id formCategoryId = [SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;

			Contact testContact = new Contact(
				FirstName = 'test',
				LastName = 'test2',
				MailingStreet = 'Some Street1',
				MailingCity = 'Some City1',
				MailingState = 'Some State1',
				MailingPostalCode = '996661',
				MailingCountry = 'Some Country1',
				X1099_Vendor__c = true,
				Default_Form_Category_Id__c = formCategoryId
			);
			insert testContact;

			Accounting_Period__c acctPeriod = new Accounting_Period__c(
				Name = Year + '-01',
				Start_Date__c = Date.newInstance(Year, 1, 1),
				End_Date__c = Date.newInstance(Year, 12, 31),
				Status__c = AccountingPeriodActions.OPEN_STATUS
			);
			insert acctPeriod;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = null;
			cd.Contact__c = testContact.Id;
			cd.Disbursement_Date__c = acctPeriod.Start_Date__c;
			cd.Debit_GL_Account__c = null;
			cd.Amount__c = 5;
			insert cd;

			Cash_Disbursement__c theNewCD = [
				SELECT
					Id,
					Alternate_Payee_Name__c,
					Payee_Street__c,
					Payee_Street2__c,
					Payee_City__c,
					Payee_State__c,
					Payee_Postal_Code__c,
					Payee_Country__c,
					Payee_Country2__c,
					Payee_City_State_Zip__c,
					Form_Category_Id__c,
					Form_1099_Box__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];

			System.assertEquals(testContact.MailingStreet, theNewCD.Payee_Street2__c);
			System.assertEquals(testContact.MailingStreet, theNewCD.Payee_Street__c);
			System.assertEquals(testContact.MailingCity, theNewCD.Payee_City__c);
			System.assertEquals(testContact.MailingState, theNewCD.Payee_State__c);
			System.assertEquals(testContact.MailingPostalCode, theNewCD.Payee_Postal_Code__c);
			System.assertEquals(testContact.MailingCountry, theNewCD.Payee_Country__c);
			System.assertEquals(testContact.MailingCountry, theNewCD.Payee_Country2__c);
			System.assertEquals(
				testContact.MailingCity + ' ' + testContact.MailingState + ' ' + testContact.MailingPostalCode,
				theNewCD.Payee_City_State_Zip__c
			);
			System.assertEquals(formCategoryId, theNewCD.Form_Category_Id__c);
		}

	}

	@IsTest
	private static void testPopulatePayeeDataFromContact1099NotValid() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createCashDisbursementBatches().createCashDisbursements();
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Integer Year = Date.today().Year();

			Id formTypeId = [
				SELECT Id, Effective_Year__c
				FROM Form_Type__mdt
				WHERE Effective_Year__c <= :Year
				ORDER BY Effective_Year__c DESC
				LIMIT 1
			]
			.Id;
			Id formCategoryId = [SELECT Id FROM Form_Category__mdt WHERE Form_Type__c = :formTypeId LIMIT 1].Id;

			Contact testContact = new Contact(
				FirstName = 'test',
				LastName = 'test2',
				MailingStreet = 'Some Street1',
				MailingCity = 'Some City1',
				MailingState = 'Some State1',
				MailingPostalCode = '996661',
				MailingCountry = 'Some Country1',
				X1099_Vendor__c = true,
				Default_Form_Category_Id__c = formCategoryId
			);
			insert testContact;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = null;
			cd.Debit_GL_Account__c = null;
			cd.Contact__c = testContact.Id;
			insert cd;

			Cash_Disbursement__c theNewCD = [
				SELECT
					Id,
					Alternate_Payee_Name__c,
					Payee_Street__c,
					Payee_Street2__c,
					Payee_City__c,
					Payee_State__c,
					Payee_Postal_Code__c,
					Payee_Country__c,
					Payee_Country2__c,
					Payee_City_State_Zip__c,
					Form_Category_Id__c,
					Form_1099_Box__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];

			System.assertEquals(testContact.MailingStreet, theNewCD.Payee_Street2__c);
			System.assertEquals(testContact.MailingStreet, theNewCD.Payee_Street__c);
			System.assertEquals(testContact.MailingCity, theNewCD.Payee_City__c);
			System.assertEquals(testContact.MailingState, theNewCD.Payee_State__c);
			System.assertEquals(testContact.MailingPostalCode, theNewCD.Payee_Postal_Code__c);
			System.assertEquals(testContact.MailingCountry, theNewCD.Payee_Country__c);
			System.assertEquals(testContact.MailingCountry, theNewCD.Payee_Country2__c);
			System.assertEquals(
				testContact.MailingCity + ' ' + testContact.MailingState + ' ' + testContact.MailingPostalCode,
				theNewCD.Payee_City_State_Zip__c
			);
			System.assertEquals(null, theNewCD.Form_Category_Id__c);
			Test.stopTest();
		}

	}

	@IsTest
	private static void testPopulatePayeeDataFromEmployee() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createCashDisbursementBatches().createCashDisbursements();
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			User testUser = TestDataSuite.createTestUser();

			testUser.Street = 'Some Street1';
			testUser.City = 'Some City1';
			testUser.State = 'Some State1';
			testUser.PostalCode = '996661';
			testUser.Country = 'Some Country1';
			update testUser;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = null;
			cd.Employee__c = testUser.Id;
			cd.Debit_GL_Account__c = null;
			insert cd;

			Cash_Disbursement__c theNewCD = [
				SELECT
					Id,
					Alternate_Payee_Name__c,
					Payee_Street__c,
					Payee_Street2__c,
					Payee_City__c,
					Payee_State__c,
					Payee_Postal_Code__c,
					Payee_Country__c,
					Payee_Country2__c,
					Payee_City_State_Zip__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];

			System.assertEquals(testUser.Street, theNewCD.Payee_Street2__c);
			System.assertEquals(testUser.Street, theNewCD.Payee_Street__c);
			System.assertEquals(testUser.City, theNewCD.Payee_City__c);
			System.assertEquals(testUser.State, theNewCD.Payee_State__c);
			System.assertEquals(testUser.PostalCode, theNewCD.Payee_Postal_Code__c);
			System.assertEquals(testUser.Country, theNewCD.Payee_Country__c);
			System.assertEquals(testUser.Country, theNewCD.Payee_Country2__c);
			System.assertEquals(
				testUser.City + ' ' + testUser.State + ' ' + testUser.PostalCode,
				theNewCD.Payee_City_State_Zip__c
			);
			Test.stopTest();
		}

	}

	@IsTest
	private static void testRequiredFieldInsertError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Accounting_Period__c = null;
			cd.Disbursement_Date__c = Date.newInstance(1970, 3, 13);

			DMLException dmlEx;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
		}

	}

	@IsTest
	private static void testRequiredFieldUpdateError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Accounting_Period__c = null;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
		}

	}

	@IsTest
	private static void testBankAccountIsRequiredOnInsert() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = null;
			cd.Disbursement_Date__c = Date.newInstance(1970, 3, 13);

			DMLException dmlEx;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
		}

	}

	@IsTest
	private static void testInsertSourceNotValidValueSetToManual() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c testCD = new Cash_Disbursement__c(
				Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
				Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
				Type__c = 'Check',
				Amount__c = 10,
				Source__c = 'NOTVALID',
				Bank_Account__c = testData.glAccounts[0].Id,
				Debit_GL_Account__c = testData.glAccounts[23].Id,
				Vendor__c = testData.accounts[0].Id,
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Status__c = 'Approved',
				Reference__c = 'the reference 0'
			);

			insert testCD;

			System.assertEquals(
				'Manual',
				[SELECT Id, Source__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Source__c
			);
		}

	}

	@IsTest
	private static void testInsertSourcePayableSetDebitGLAccountAPControl() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
			testCD.Debit_GL_Account__c = testData.glAccounts[1].Id;

			CashDisbursementActions.isSourcedFromPayables = true;
			insert testCD;
			CashDisbursementActions.isSourcedFromPayables = false;
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c,
				'On insert if the Source is Payable and the Debit GL Account is not equal to the AP Control Account, set the Debit GL Account to the AP Control Account'
			);
		}
	}

	@IsTest
	private static void testSourceManualDebitGLAccountAndIsAPControlSetDebitGLAccountPrepaid() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
			testCD.AcctSeed__Debit_GL_Account__c = null;
			testCD.Source__c = 'Manual';

			insert testCD;
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c,
				'On insert if the Source is Manual and the Debit GL Account is equal to the AP Control Account, set the Debit GL Account to the Prepaid Expense GL Account'
			);
		}
	}

	@IsTest
	private static void testSourceManualDebitGLAccountNoPopulated() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		//clear out the PREPAID_EXPENSE_GL_ACCOUNT becuase it is not required at the default level
		List<GL_Account_Default__c> prePaidExpGLDefs = [
			SELECT Id, GL_Account__r.Name
			FROM GL_Account_Default__c
			WHERE GL_Account_Specification__c = :GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT
		];

		delete prePaidExpGLDefs;
		//Reset the GLAccountDefaultsHandler
		GLAccountDefaultsHandler.instance = null;

		test.startTest();
		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c testCD = new Cash_Disbursement__c(
				Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[1].Id,
				Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
				Type__c = 'Check',
				Source__c = 'Manual',
				Amount__c = 50,
				Bank_Account__c = testData.glAccounts[0].Id,
				Employee__c = UserInfo.getUserId(),
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED,
				Reference__c = 'test reference'
			);

			try {
				insert testCD;
			} catch (DmlException e) {
				System.assertEquals(
					String.format(
						Label.ERR_DEFAULT_PREPAID_EXPENSE_GL_ACCOUNT_REQUIRED,
						new List<String>{ 'Cash Disbursement' }
					),
					e.getDmlMessage(0)
				);
			}

			System.assertEquals(null, testCD.Id);
		}
		test.stopTest();
	}

	@IsTest
	private static void testSetSourceAndDebitGLAccountCloneInsert() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			testData.createCashDisbursementBatches().createCashDisbursements();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Debit_GL_Account__c = null;
			insert cd;

			System.assertEquals('Manual', [SELECT Id, Source__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Source__c);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Debit_GL_Account__c
			);
			Test.stopTest();
		}
	}

	@IsTest
	private static void testBankAccountIsRequiredOnUpdate() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Bank_Account__c = null;
			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SObjectActions.REQUIRED_FIELD_ERROR, dmlEx.getDMLMessage(0));
		}

	}

	@IsTest
	private static void testPreventUpdateActionPostedError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[4].Id;
			update testData.cashDisbursements[0];

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> postResults = postHandler.post(
				new List<Cash_Disbursement__c>{ testData.cashDisbursements[0] }
			);
			System.assertEquals(true, postResults[0].isSuccess);

			System.assertEquals(
				AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
				[
					SELECT Accounting_Period__r.Status__c, Status__c
					FROM Cash_Disbursement__c
					WHERE Id = :testData.cashDisbursements[0].Id
				]
				.Status__c
			);
			System.assertNotEquals(
				0,
				[SELECT COUNT() FROM Transaction__c WHERE Cash_Disbursement__c = :testData.cashDisbursements[0].Id]
			);
			// Test update no error since no fields changed.
			Cash_Disbursement__c cd = [
				SELECT Accounting_Period__r.Status__c, Status__c
				FROM Cash_Disbursement__c
				WHERE Id = :testData.cashDisbursements[0].Id
			];

			DMLException dmlEx;
			try {
				update cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(null, dmlEx);

			// Test update error since attempted to change protected field.
			try {
				testData.cashDisbursements[0].Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();
			System.assertEquals(
				String.format(
					SourceDocumentUpdateFieldValidator.POSTED_UPDATE_ERROR,
					new List<String>{ sfu.formatFieldStrings(sfu.lockedUpdateFieldsPosted), sfu.postedStatusValues[0] }
				),
				dmlEx.getDMLMessage(0)
			);
		}
	}

	@IsTest
	private static void preventUpdateAmountFieldError() {
		TestDataSuite testData = TestDataSuite.getInstance();

		Test.startTest();
		testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements();
		testData.createApDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[5].Amount__c = testData.cashDisbursements[5].Amount__c + 1;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[5];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					CashDisbursementActions.NON_UPDATE_FIELDS_AP_UPDATE_ERROR,
					new List<String>{
						FinancialSuiteUtils.formatFieldStrings(
							CashDisbursementActions.NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP
						)
					}
				),
				dmlEx.getDMLMessage(0)
			);
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPreventUpdateDebitGLAccountAPDisbursementsExist() {
		TestDataSuite testData = TestDataSuite.getInstance();

		Test.startTest();
		testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements();
		testData.createApDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Debit_GL_Account__c = testData.glAccounts[22].Id;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					CashDisbursementActions.NON_UPDATE_FIELDS_AP_UPDATE_ERROR,
					new List<String>{
						FinancialSuiteUtils.formatFieldStrings(
							CashDisbursementActions.NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP
						)
					}
				),
				dmlEx.getDMLMessage(0)
			);
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPreventUpdateVendorAPDisbursementsExist() {
		TestDataSuite testData = TestDataSuite.getInstance();

		Test.startTest();
		testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements();
		testData.createApDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Vendor__c = testData.accounts[1].Id;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					CashDisbursementActions.NON_UPDATE_FIELDS_AP_UPDATE_ERROR,
					new List<String>{
						FinancialSuiteUtils.formatFieldStrings(
							CashDisbursementActions.NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP
						)
					}
				),
				dmlEx.getDMLMessage(0)
			);
		}
		Test.stopTest();
	}

	@IsTest
	private static void testPreventUpdatePeriodAPDisbursementsExist() {
		TestDataSuite testData = TestDataSuite.getInstance();

		Test.startTest();
		testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements();
		testData.createApDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[3].Id;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					CashDisbursementActions.NON_UPDATE_FIELDS_AP_UPDATE_ERROR,
					new List<String>{
						FinancialSuiteUtils.formatFieldStrings(
							CashDisbursementActions.NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP
						)
					}
				),
				dmlEx.getDMLMessage(0)
			);
		}
		Test.stopTest();
	}

	@IsTest
	private static void testUpdateAmountFieldNoAPDisbursementsExist() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c cd = testData.cashDisbursements[5].clone(false, true);
			insert cd;

			cd = [SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];
			Decimal newAmount = cd.Amount__c + 1;
			cd.Amount__c = newAmount;
			update cd;

			System.assertEquals(
				newAmount,
				[SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Amount__c
			);
		}

	}

	@IsTest
	private static void testUpdateAmountOverScaleCashDisbursementUpdateSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			List<Cash_Disbursement__c> cashDisbursements = new List<Cash_Disbursement__c>();
			cashDisbursements.add(
				new Cash_Disbursement__c(
					Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
					Disbursement_Date__c = Date.newinstance(1991, 11, 2),
					Type__c = 'Check',
					Amount__c = 12,
					Source__c = 'Payable',
					Bank_Account__c = testData.glAccounts[0].Id,
					Vendor__c = testData.accounts[0].Id,
					Status__c = 'In Process'
				)
			);
			insert cashDisbursements;

			System.assertEquals(
				testData.acctPeriods[1].Id,
				[
					SELECT Accounting_Period__c
					FROM Cash_Disbursement__c
					WHERE Id = :cashDisbursements[0].Id
				]
				.Accounting_Period__c
			);
		}

	}

	@IsTest
	private static void testPreventUpdateActionPostedNoChangeSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[4].Id;
			update testData.cashDisbursements[0];

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> postResults = postHandler.post(
				new List<Cash_Disbursement__c>{ testData.cashDisbursements[0] }
			);
			System.assertEquals(true, postResults[0].isSuccess);

			System.assertEquals(
				AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
				[
					SELECT Accounting_Period__r.Status__c, Status__c
					FROM Cash_Disbursement__c
					WHERE Id = :testData.cashDisbursements[0].Id
				]
				.Status__c
			);

			// Test update no error since no fields changed.
			Cash_Disbursement__c cr = [
				SELECT Accounting_Period__r.Status__c, Status__c
				FROM Cash_Disbursement__c
				WHERE Id = :testData.cashDisbursements[0].Id
			];
			DMLException dmlEx;
			try {
				update cr;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(null, dmlEx);
		}
	}

	@IsTest
	private static void testUpdateAccountingPeriodSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[4].Id;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(null, dmlEx);
		}
	}

	@IsTest
	private static void testUpdateSourcePayableAmountSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createPayables(false)
				.createCashDisbursementBatches()
				.createCashDisbursements()
				.createApDisbursements();
			delete testData.apDisbursements[3];

			System.assertEquals(
				10,
				[SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Amount__c
			);

			AP_Disbursement__c apd = new AP_Disbursement__c(
				Account_Payable__c = testData.payables[5].Id,
				Cash_Disbursement__c = testData.cashDisbursements[0].Id,
				Accounting_Period__c = testData.acctPeriods[1].Id,
				Paid_Amount__c = 60
			);

			insert apd;

			System.assertEquals(
				70,
				[SELECT Id, Amount__c FROM Cash_Disbursement__c WHERE Id = :testData.cashDisbursements[0].Id].Amount__c
			);
		}
	}

	@IsTest
	private static void testChangeSourceManualToPayableSetDebitGLAccountAPControl() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c testCD = testData.cashDisbursements[5];
			testCD.Source__c = 'Payable';

			update testCD;
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c,
				'On update if the Source is changed from Manual to Payable and the Debit GL Account is not equal to the AP Control Account, set the Debit GL Account to the AP Control Account'
			);
		}
	}

	@IsTest
	private static void testChangeSourcePayableToManualSetPrepaidGLAccountIfDebitGLAccountIsAPControl() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c testCD = testData.cashDisbursements[0];
			testCD.Source__c = 'Manual';
			testCD.AcctSeed__Debit_GL_Account__c = null;
			update testCD;
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c,
				'On update if the Source is changed from Payable to Manual and the Debit GL Account is equal to the AP Control Account, set the Debit GL Account to the Prepaid GL Account'
			);
		}
	}

	@IsTest
	private static void testChangeSourcePayableDebitGLAccountToNonAPControlAccountRevertChange() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Cash_Disbursement__c testCD = testData.cashDisbursements[0];
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
				testCD.Debit_GL_Account__c
			);

			testCD.Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)
				?.GL_Account__c;
			update testCD;

			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c,
				'On update if the Debit GL Account is changed and the Source is equal to Payable, set the Debit GL Account to the AP Control GL Account'
			);
		}
	}

	@IsTest
	private static void testDeleteCashDisbursementBatchUpdateAPStatus() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createPayables().createCashDisbursementBatches().createCashDisbursements();
			testData.payables[0].Payment_Status__c = 'Paid';
			testData.payables[0].Status__c = 'In Process';
			update testData.payables[0];

			delete testData.cashDisbursementBatch[0];

			System.assertEquals(
				'Unpaid',
				[
					SELECT Payment_Status__c
					FROM Account_Payable__c
					WHERE Id = :testData.payables[0].Id
				]
				.Payment_Status__c
			);
			Test.stopTest();
		}

	}

	@IsTest
	private static void testDeleteCashDisbursementUpdateAPStatus() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createPayables().createCashDisbursementBatches().createCashDisbursements();
			Account_Payable__c testAP = [
				SELECT Id, Payment_Status__c, Net_Amount__c, Status__c
				FROM Account_Payable__c
				WHERE Id = :testData.payables[0].Id
				LIMIT 1
			];
			testAP.Status__c = 'Approved';
			update testAP;

			Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);

			CashDisbursementActions.isSourcedFromPayables = true;
			insert testCD;
			CashDisbursementActions.isSourcedFromPayables = false;

			AccountPayablePostTransaction apt = new AccountPayablePostTransaction(
				new ApexPages.StandardController(testAP)
			);

			apt.post();

			//Need to insert new APD to have the "Paid" Payable record
			AP_Disbursement__c testAPD = new AP_Disbursement__c(
				Account_Payable__c = testAP.Id,
				Cash_Disbursement__c = testCD.Id,
				Paid_Amount__c = testAP.Net_Amount__c
			);
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			System.assertEquals(
				'Payable',
				[SELECT Id, Source__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Source__c
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c
			);
			CashDisbursementActions.isSourcedFromPayables = true;
			insert testAPD;
			CashDisbursementActions.isSourcedFromPayables = false;

			testAP = [
				SELECT Payment_Status__c
				FROM Account_Payable__c
				WHERE Id = :testAP.Id
				LIMIT 1
			];

			System.assertEquals('Paid', testAP.Payment_Status__c);

			delete testCD;
			testAP = [
				SELECT Payment_Status__c
				FROM Account_Payable__c
				WHERE Id = :testAP.Id
				LIMIT 1
			];
			System.assertEquals('Unpaid', testAP.Payment_Status__c);
			Test.stopTest();
		}
	}

	@IsTest
	private static void testCashDisbursementUnpostedInsertClosedAccountingPeriodSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.acctPeriods[0].Status__c = AccountingPeriodActions.CLOSED_STATUS;
			update testData.acctPeriods[0];

			System.assertEquals(
				AccountingPeriodActions.CLOSE_INTERIM_STATUS,
				[
					SELECT Id, Status__c
					FROM Accounting_Period__c
					WHERE Id = :testData.acctPeriods[0].Id
				]
				.Status__c
			);

			Test.stopTest();

			System.assertEquals(
				AccountingPeriodActions.CLOSED_STATUS,
				[
					SELECT Id, Status__c
					FROM Accounting_Period__c
					WHERE Id = :testData.acctPeriods[0].Id
				]
				.Status__c
			);

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Disbursement_Date__c = Date.newInstance(1991, 10, 1);
			cd.Accounting_Period__c = null;
			cd.Debit_GL_Account__c = null;
			cd.Amount__c = 5;

			DMLException dmlEx;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(null, dmlEx);
		}

	}

	@IsTest
	private static void testCashDisbursementUnpostedDeleteSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[4].Id;
			update testData.cashDisbursements[0];

			DMLException dmlEx;
			try {
				delete testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(null, dmlEx);
		}

	}

	@IsTest
	private static void testPreventDeleteIsApdExists() {
		TestDataSuite testData = TestDataSuite.getInstance();

		Test.startTest();
		testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements();
		testData.createApDisbursements();

		System.runAs(testData.users.get(1)) {
			DMLException dmlEx;
			try {
				delete testData.cashDisbursements[5];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.ATTEMPT_TO_DELETE_APPLIED_ERROR, dmlEx.getDmlMessage(0));
		}
		Test.stopTest();
	}

	@IsTest
	private static void testCashDisbursementPostedDeleteError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Accounting_Period__c = testData.acctPeriods[4].Id;
			update testData.cashDisbursements[0];

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> postResults = postHandler.post(
				new List<Cash_Disbursement__c>{ testData.cashDisbursements[0] }
			);
			System.assertEquals(true, postResults[0].isSuccess);

			System.assertEquals(
				AbstractPostHandler.DEFAULT_POSTING_STATUS_POSTED,
				[
					SELECT Accounting_Period__r.Status__c, Status__c
					FROM Cash_Disbursement__c
					WHERE Id = :testData.cashDisbursements[0].Id
				]
				.Status__c
			);

			DMLException dmlEx;
			try {
				delete testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SourceDocumentUpdateFieldValidator.POSTED_DELETE_ERROR, dmlEx.getDMLMessage(0));
		}

	}

	@IsTest
	private static void testRequiredVendorContactEmployeeInsertError() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.createCashDisbursementBatches().createCashDisbursements();

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = null;
			cd.Contact__c = null;
			cd.Employee__c = null;
			cd.AcctSeed__Debit_GL_Account__c = null;

			// Test insert error
			DMLException dmlEx;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.REQUIRED_PAYEE_ERROR, dmlEx.getDmlMessage(0));
			Test.stopTest();
		}

	}

	@IsTest
	private static void testRequiredVendorContactEmployeeUpdateError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Vendor__c = null;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.REQUIRED_PAYEE_ERROR, dmlEx.getDmlMessage(0));
		}

	}

	@IsTest
	private static void testMultiplePayeeVendorContactEmployeeInsertError() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.createCashDisbursementBatches().createCashDisbursements();

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = testData.accounts[0].Id;
			cd.Contact__c = testData.contacts[0].Id;
			cd.Employee__c = null;
			cd.Debit_GL_Account__c = null;

			// Test insert error
			DMLException dmlEx;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.MULTIPLE_PAYEE_ERROR, dmlEx.getDmlMessage(0));

			cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = testData.accounts[0].Id;
			cd.Contact__c = null;
			cd.Employee__c = testData.users[0].Id;
			cd.Debit_GL_Account__c = null;

			// Test insert error
			dmlEx = null;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.MULTIPLE_PAYEE_ERROR, dmlEx.getDmlMessage(0));

			cd = testData.cashDisbursements[0].clone(false, true);
			cd.Vendor__c = null;
			cd.Contact__c = testData.contacts[0].Id;
			cd.Employee__c = testData.users[0].Id;
			cd.Debit_GL_Account__c = null;

			// Test insert error
			dmlEx = null;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.MULTIPLE_PAYEE_ERROR, dmlEx.getDmlMessage(0));
			Test.stopTest();
		}

	}

	@IsTest
	private static void testMultiplePayeeVendorContactEmployeeUpdateError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Vendor__c = testData.accounts[0].Id;
			testData.cashDisbursements[0].Contact__c = testData.contacts[0].Id;
			testData.cashDisbursements[0].Employee__c = null;

			// Test update error
			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.MULTIPLE_PAYEE_ERROR, dmlEx.getDmlMessage(0));

			testData.cashDisbursements[0].Vendor__c = testData.accounts[0].Id;
			testData.cashDisbursements[0].Contact__c = null;
			testData.cashDisbursements[0].Employee__c = testData.users[0].Id;

			// Test update error
			dmlEx = null;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.MULTIPLE_PAYEE_ERROR, dmlEx.getDmlMessage(0));

			testData.cashDisbursements[0].Vendor__c = null;
			testData.cashDisbursements[0].Contact__c = testData.contacts[0].Id;
			testData.cashDisbursements[0].Employee__c = testData.users[0].Id;

			// Test update error
			dmlEx = null;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(CashDisbursementActions.MULTIPLE_PAYEE_ERROR, dmlEx.getDmlMessage(0));
		}

	}

	@IsTest
	private static void testCashDisbursementPreventUpdateBankReconciliationFieldSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankReconciliations()
			.createCashDisbursementBatches()
			.createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Bank_Reconciliation__c = testData.bankReconciliations[0].Id;

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();
			System.assertEquals(
				String.format(
					SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
					new List<String>{ sfu.formatFieldStrings(sfu.lockedUpdateFields) }
				),
				dmlEx.getDMLMessage(0)
			);
		}

	}

	@IsTest
	private static void testPaymentStatusManualModifications() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[0].Payment_Status__c = 'Void';

			DMLException dmlEx;
			try {
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			SourceDocumentUpdateFieldValidator sfu = new CashDisbursementFieldUpdateValidator();
			System.assertEquals(
				String.format(
					SourceDocumentUpdateFieldValidator.UPDATE_ERROR,
					new List<String>{ sfu.formatFieldStrings(sfu.lockedUpdateFields) }
				),
				dmlEx.getDMLMessage(0)
			);
		}

	}

	@IsTest
	private static void testCashDisbursementSetDefaultFieldValuesSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankReconciliations()
			.createCashDisbursementBatches()
			.createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			String defaultValue = 'In Process';
			for (
				Schema.PicklistEntry pickListEntry : Cash_Disbursement__c.Status__c.getDescribe().getPicklistValues()
			) {
				if (pickListEntry.isDefaultValue() && pickListEntry.getValue() != 'Posted') {
					defaultValue = pickListEntry.getValue();
				}
			}

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
			cd.Status__c = 'Posted';
			cd.Payment_Status__c = 'Void';
			cd.Cleared_Date__c = System.today();
			cd.Debit_GL_Account__c = null;

			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Cash_Disbursement__c.Status__c,
						Cash_Disbursement__c.Payment_Status__c,
						Cash_Disbursement__c.Bank_Reconciliation__c,
						Cash_Disbursement__c.Debit_GL_Account__c
					}
				);
			insert cd;
			TriggerObserver.reset();
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers[0].Id
			);
			System.assertEquals(
				null,
				[SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Bank_Reconciliation__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Cleared_Date__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Check_Number__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Check_Number__c
			);
			System.assertEquals(
				defaultValue,
				[SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Status__c
			);
			System.assertEquals(
				'Paid',
				[SELECT Id, Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Payment_Status__c
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Debit_GL_Account__c
			);

			cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
			cd.Status__c = null;
			cd.Payment_Status__c = 'Void';
			cd.Cleared_Date__c = System.today();
			cd.Debit_GL_Account__c = null;

			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Cash_Disbursement__c.Status__c,
						Cash_Disbursement__c.Payment_Status__c,
						Cash_Disbursement__c.Bank_Reconciliation__c,
						Cash_Disbursement__c.Debit_GL_Account__c
					}
				);
			insert cd;
			TriggerObserver.reset();

			System.assertEquals(
				null,
				[SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Bank_Reconciliation__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Cleared_Date__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Check_Number__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Check_Number__c
			);
			System.assertEquals(
				defaultValue,
				[SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Status__c
			);
			System.assertEquals(
				'Paid',
				[SELECT Id, Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Payment_Status__c
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Debit_GL_Account__c
			);

			cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
			cd.Status__c = defaultValue;
			cd.Payment_Status__c = 'Void';
			cd.Cleared_Date__c = System.today();
			cd.Debit_GL_Account__c = null;

			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Cash_Disbursement__c.Status__c,
						Cash_Disbursement__c.Payment_Status__c,
						Cash_Disbursement__c.Bank_Reconciliation__c,
						Cash_Disbursement__c.Debit_GL_Account__c
					}
				);
			insert cd;
			TriggerObserver.reset();

			System.assertEquals(
				null,
				[SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Bank_Reconciliation__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Cleared_Date__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Check_Number__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Check_Number__c
			);
			System.assertEquals(
				defaultValue,
				[SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Status__c
			);
			System.assertEquals(
				'Paid',
				[SELECT Id, Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Payment_Status__c
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Debit_GL_Account__c
			);

			cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Reconciliation__c = testData.bankReconciliations[0].Id;
			cd.Status__c = 'Arbitrary';
			cd.Payment_Status__c = 'Void';
			cd.Cleared_Date__c = System.today();
			cd.Debit_GL_Account__c = null;

			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Cash_Disbursement__c.Status__c,
						Cash_Disbursement__c.Payment_Status__c,
						Cash_Disbursement__c.Bank_Reconciliation__c,
						Cash_Disbursement__c.Debit_GL_Account__c
					}
				);
			insert cd;
			TriggerObserver.reset();

			System.assertEquals(
				null,
				[SELECT Id, Bank_Reconciliation__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Bank_Reconciliation__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Cleared_Date__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Cleared_Date__c
			);
			System.assertEquals(
				null,
				[SELECT Id, Check_Number__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Check_Number__c
			);
			System.assertEquals(
				'Arbitrary',
				[SELECT Id, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Status__c
			);
			System.assertEquals(
				'Paid',
				[SELECT Id, Payment_Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Payment_Status__c
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.PREPAID_EXPENSE_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Debit_GL_Account__c
			);
		}

	}

	@IsTest
	private static void testSetSourceFieldIfNotManualOrPayableToManualInsert() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c cashDisbursement = new Cash_Disbursement__c(
				Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
				Disbursement_Date__c = Date.newInstance(1991, 11, 2),
				Type__c = 'Check',
				Bank_Account__c = testData.glAccounts[0].Id,
				Vendor__c = testData.accounts[0].Id,
				Status__c = 'In Process',
				Source__c = 'THIS IS NOT AN ACCEPTABLE VALUE',
				Debit_GL_Account__c = testData.glAccounts[23].Id,
				Amount__c = 20.00,
				Check_Number__c = 2300
			);
			insert cashDisbursement;

			System.assertEquals(
				'Manual',
				[SELECT Id, Source__c FROM Cash_Disbursement__c WHERE Id = :cashDisbursement.Id].Source__c
			);
		}
	}

	@IsTest
	private static void testSetPreventUpdateStatusFieldPostedError() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			DMLException dmlEx = null;
			try {
				testData.cashDisbursements[0].Status__c = 'Posted';
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(SourceDocumentUpdateFieldValidator.UPDATE_STATUS_ERROR, dmlEx.getDMLMessage(0));
		}

	}

	@IsTest
	private static void testResolveAccountingPeriodCashDisbursement() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			List<Cash_Disbursement__c> cashDisbursements = new List<Cash_Disbursement__c>();
			cashDisbursements.add(
				new Cash_Disbursement__c(
					Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
					Disbursement_Date__c = Date.newinstance(1991, 11, 2),
					Type__c = 'Check',
					Amount__c = 12,
					Source__c = 'Account Payable',
					Bank_Account__c = testData.glAccounts[0].Id,
					Vendor__c = testData.accounts[0].Id,
					Status__c = 'In Process'
				)
			);
			insert cashDisbursements;

			System.assertEquals(
				testData.acctPeriods[1].Id,
				[
					SELECT Accounting_Period__c
					FROM Cash_Disbursement__c
					WHERE Id = :cashDisbursements[0].Id
				]
				.Accounting_Period__c
			);
		}

	}

	@IsTest
	private static void testValidateCashDisbursementBatchHasTheSameCurrency() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance();

			System.runAs(testData.users.get(1)) {
				Test.startTest();
				testData.enableMultiCurrency().createCashDisbursementBatches().createCashDisbursements();

				Accounting_Settings__c accountingSettings = testData.settings;
				accountingSettings.Cash_Disbursement_Source__c = 'Manual';
				update accountingSettings;

				String newCurrency = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(newCurrency)) {
					return;
				}
				Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone(false, true);
				testCD.put('CurrencyIsoCode', newCurrency);
				testCD.AcctSeed__Debit_GL_Account__c = null;

				DmlException dmlEx;
				try {
					insert testCD;
				} catch (DmlException ex) {
					dmlEx = ex;
				}

				System.assertEquals(CashDisbursementActions.NOT_EQUAL_CURRENCY_ERROR, DmlEx.getDmlMessage(0));
				Test.stopTest();
			}
		} catch (Exception ex) {
		}
	}

	@IsTest
	private static void testPreventUpdateCurrencyIfPosted_MC() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

			System.runAs(testData.users.get(1)) {
				Test.startTest();
				testData.createCashDisbursementBatches().createCashDisbursements();
				String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(newCurrencyIsoCode)) {
					return;
				}
				Cash_Disbursement__c testCD = new Cash_Disbursement__c(
					Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[1].Id,
					Disbursement_Date__c = Date.today(),
					Type__c = 'Check',
					Amount__c = 100,
					Bank_Account__c = testData.glAccounts[0].Id,
					Debit_GL_Account__c = testData.glAccounts[23].Id,
					Vendor__c = testData.accounts[0].Id,
					Accounting_Period__c = testData.acctPeriods[0].Id,
					Status__c = 'Approved',
					Reference__c = 'the reference 666'
				);
				insert testCD;

				AbstractPostHandler postHandler = new CashDisbursementPostHandler();
				List<PostResult> postResults = postHandler.post(new List<Cash_Disbursement__c>{ testCD });
				System.assertEquals(true, postResults[0].isSuccess);

				Cash_Disbursement__c postedCD = [SELECT Id FROM Cash_Disbursement__c WHERE Id = :testCD.Id LIMIT 1];
				postedCD.put('CurrencyIsoCode', newCurrencyIsoCode);
				DmlException dmlEx;
				try {
					update postedCD;
				} catch (DmlException ex) {
					dmlEx = ex;
				}

				System.assertNotEquals(null, dmlEx);
				Test.stopTest();
			}
		} catch (Exception ex) {
		}
	}

	@IsTest
	private static void testSetCurrencyIsoCodeIfNullUpdate_MC() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance();
			System.runAs(testData.users.get(1)) {
				Test.startTest();
				testData.enableMultiCurrency().createCashDisbursementBatches().createCashDisbursements();
				String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(newCurrencyIsoCode)) {
					return;
				}
				Cash_Disbursement__c testCD = new Cash_Disbursement__c(
					Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[1].Id,
					Disbursement_Date__c = Date.today(),
					Type__c = 'Check',
					Amount__c = 100,
					Bank_Account__c = testData.glAccounts[0].Id,
					Debit_GL_Account__c = testData.glAccounts[23].Id,
					Vendor__c = testData.accounts[0].Id,
					Accounting_Period__c = testData.acctPeriods[0].Id,
					Status__c = 'Approved',
					Reference__c = 'the reference 666'
				);
				insert testCD;

				testCD.put('CurrencyIsoCode', null);
				update testCD;
				testCD = Database.query(
					'SELECT Id, CurrencyIsoCode FROM Cash_Disbursement__c WHERE Id = :testCD.Id LIMIT 1'
				);

				System.assertNotEquals(null, testCD.get('CurrencyIsoCode'));
				Test.stopTest();
			}
		} catch (Exception ex) {
		}
	}

	@IsTest
	private static void testCashDisbursementNoNullPointerExceptionInsert() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			DMLException dmlEx;
			try {
				Cash_Disbursement__c cd = new Cash_Disbursement__c();
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
		}
	}

	@IsTest
	private static void testCashDisbursementNoNullPointerExceptionInsert_MC() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance().enableMultiCurrency();

			System.runAs(testData.users.get(1)) {
				DMLException dmlEx;

				Cash_Disbursement__c cd = new Cash_Disbursement__c();

				try {
					insert cd;
				} catch (DMLException ex) {
					dmlEx = ex;
				}
				System.assert(!dmlEx.getDmlMessage(0).contains('System.NullPointerException'));
			}
		} catch (Exception ex) {
		}
	}

	@IsTest
	private static void testNormalizeNumericAndCurrencyFieldsInsert() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Cash_Disbursement__c cashDisbursement = new Cash_Disbursement__c(
				Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
				Disbursement_Date__c = Date.newInstance(1991, 11, 2),
				Type__c = 'Check',
				Bank_Account__c = testData.glAccounts[0].Id,
				Vendor__c = testData.accounts[0].Id,
				Status__c = 'In Process',
				Debit_GL_Account__c = testData.glAccounts[23].Id,
				Amount__c = 20.989342348934,
				Currency_Conversion_Rate__c = 10.236746723674344,
				Check_Number__c = 23.423423545452423
			);

			insert cashDisbursement;

			Cash_Disbursement__c newCashDisbursement = [
				SELECT Id, Amount__c, Currency_Conversion_Rate__c, Check_Number__c
				FROM Cash_Disbursement__c
				WHERE Id = :cashDisbursement.Id
			];

			System.assertEquals(20.99, newCashDisbursement.Amount__c);
			System.assertEquals(10.236747, newCashDisbursement.Currency_Conversion_Rate__c);
		}

	}

	@IsTest
	private static void testNormalizeNumericAndCurrencyFieldsUpdate() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			testData.cashDisbursements[5].Amount__c = 20.989342348934;
			testData.cashDisbursements[5].Currency_Conversion_Rate__c = 10.236746723674344;

			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Cash_Disbursement__c.Amount__c,
						Cash_Disbursement__c.Currency_Conversion_Rate__c
					}
				);
			update testData.cashDisbursements[5];
			TriggerObserver.reset();

			Cash_Disbursement__c newCashDisbursement = [
				SELECT Id, Amount__c, Currency_Conversion_Rate__c, Check_Number__c
				FROM Cash_Disbursement__c
				WHERE Id = :testData.cashDisbursements[5].Id
			];

			System.assertEquals(20.99, newCashDisbursement.Amount__c);
			System.assertEquals(10.236747, newCashDisbursement.Currency_Conversion_Rate__c);
		}

	}

	@IsTest
	private static void testCreateWithSourceSetPayableSuccess() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createPayables(true);
		System.runAs(testData.users.get(1)) {
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Cash_Disbursement__c testCD = new Cash_Disbursement__c(
				Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
				Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
				Type__c = 'Check',
				Amount__c = 165,
				Source__c = 'Payable',
				Bank_Account__c = testData.glAccounts[0].Id,
				Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
					?.GL_Account__c,
				Vendor__c = testData.accounts[0].Id,
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Reference__c = 'ref-xxx-ref'
			);

			Test.startTest();
			insert testCD;
			System.assertEquals(1, [SELECT COUNT() FROM Cash_Disbursement__c WHERE Id = :testCD.Id]);
			System.assertEquals(
				'Payable',
				[SELECT Id, Source__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Source__c
			);
			System.assertEquals(
				defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)?.GL_Account__c,
				[SELECT Id, Debit_GL_Account__c FROM Cash_Disbursement__c WHERE Id = :testCD.Id].Debit_GL_Account__c
			);
			Test.stopTest();
		}
	}

	@IsTest
	private static void testPreventUpdateSourceWithAPDFieldError() {
		TestDataSuite testData = TestDataSuite.getInstance();
		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createCashDisbursementBatches().createPayables(true);
			Map<String, GL_Account_Default__c> defaultsBySpecDevNames = GLAccount.glAccountDefaultsMapByLedgerId(
				testData.ledgers.get(0).Id
			);
			Cash_Disbursement__c testCD = new Cash_Disbursement__c(
				Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id,
				Disbursement_Date__c = testData.acctPeriods[0].Start_Date__c,
				Type__c = 'Check',
				Amount__c = 165,
				Source__c = 'Payable',
				Bank_Account__c = testData.glAccounts[0].Id,
				Debit_GL_Account__c = defaultsBySpecDevNames.get(GLAccountDefaultsHandler.AP_CONTROL_GL_ACCOUNT)
					?.GL_Account__c,
				Vendor__c = testData.accounts[0].Id,
				Accounting_Period__c = testData.acctPeriods[0].Id,
				Reference__c = 'ref-xxx-ref'
			);
			CashDisbursementActions.isSourcedFromPayables = true;
			insert testCD;
			CashDisbursementActions.isSourcedFromPayables = false;

			AP_Disbursement__c testAPD = new AP_Disbursement__c(
				Account_Payable__c = testData.payables[0].Id,
				Cash_Disbursement__c = testCD.Id,
				Paid_Amount__c = 100
			);
			insert testAPD;

			DMLException dmlEx;
			try {
				testCD.Source__c = 'Manual';
				update testCD;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(
				String.format(
					CashDisbursementActions.NON_UPDATE_FIELDS_AP_UPDATE_ERROR,
					new List<String>{
						FinancialSuiteUtils.formatFieldStrings(
							CashDisbursementActions.NON_UPDATE_FIELDS_IF_ASSOCIATED_WITH_AP
						)
					}
				),
				dmlEx.getDMLMessage(0)
			);
			Test.stopTest();
		}
	}

	@IsTest
	public static void testAllowOverCDByAPDPositive() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements(true);

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone();
			testCD.Debit_GL_Account__c = null;
			testCD.Amount__c = 5;
			insert testCD;

			AP_Disbursement__c testAPD = new AP_Disbursement__c(
				Account_Payable__c = testData.payables[0].Id,
				Cash_Disbursement__c = testCD.Id,
				Paid_Amount__c = 8
			);
			insert testAPD;

			System.assertEquals(
				[SELECT Paid_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Paid_Amount__c,
				testAPD.Paid_Amount__c
			);
			Test.stopTest();
		}
	}

	@IsTest
	public static void testAllowOverCDByAPDNegative() {
		TestDataSuite testData = TestDataSuite.getInstance();
		System.runAs(testData.users.get(1)) {
			Test.startTest();
			testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements(true);

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Cash_Disbursement__c testCD = testData.cashDisbursements[0].clone();
			testCD.Debit_GL_Account__c = null;
			testCD.Source__c = 'Manual';
			testCD.Amount__c = 5;
			insert testCD;

			AP_Disbursement__c testAPD = new AP_Disbursement__c(
				Account_Payable__c = testData.payables[0].Id,
				Cash_Disbursement__c = testCD.Id,
				Paid_Amount__c = -8
			);

			insert testAPD;
			System.assertEquals(
				[SELECT Paid_Amount__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Paid_Amount__c,
				testAPD.Paid_Amount__c
			);
			Test.stopTest();
		}
	}

	@IsTest
	private static void testSetVoidedDateNullOnInsert() {
		TestDataSuite testData = TestDataSuite.getInstance();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			testData.createPayables(true).createCashDisbursementBatches().createCashDisbursements(true);

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Void_Date__c = System.today();
			cd.Debit_GL_Account__c = null;

			DMLException dmlEx;
			try {
				insert cd;
			} catch (DMLException ex) {
				dmlEx = ex;
			}

			System.assertEquals(null, [SELECT Void_Date__c FROM Cash_Disbursement__c WHERE Id = :cd.Id].Void_Date__c);
			Test.stopTest();
		}

	}

	@IsTest
	public static void testSetCurrencyIsoCodeNullInsert_MC() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance();

			System.runAs(testData.users[1]) {
				Test.startTest();
				testData.enableMultiCurrency() //will throw an exception in case of non-MC org
					.createCashDisbursementBatches()
					.createCashDisbursements();

				Accounting_Settings__c accountingSettings = testData.settings;
				accountingSettings.Cash_Disbursement_Source__c = 'Manual';
				update accountingSettings;

				String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(newCurrencyIsoCode)) {
					return;
				}

				Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
				cd.put('CurrencyIsoCode', null);
				cd.AcctSeed__Debit_GL_Account__c = null;

				try {
					insert cd;
					Id cdId = cd.Id;
					cd = Database.query(
						'SELECT Id, CurrencyIsoCode, Cash_Disbursement_Batch__r.CurrencyIsoCode FROM Cash_Disbursement__c WHERE Id = :cdId'
					);
				} catch (DmlException ex) {
				} catch (QueryException ex) {
				}

				System.assertNotEquals(null, cd);
				System.assertNotEquals(null, cd.get('CurrencyIsoCode'));
				System.assertEquals(
					cd.getSObject('Cash_Disbursement_Batch__r').get('CurrencyIsoCode'),
					cd.get('CurrencyIsoCode')
				);
				Test.stopTest();
			}
		} catch (Exception ex) {
			//just skip this test if it is non-MC org
		}
	}

	@IsTest
	public static void testSetCurrencyIsoCodeNullUpdate_MC() {
		try {
			TestDataSuite testData = TestDataSuite.getInstance();
			System.runAs(testData.users[1]) {
				Test.startTest();
				testData.enableMultiCurrency() //will throw an exception in case of non-MC org
					.createCashDisbursementBatches()
					.createCashDisbursements();
				String newCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(newCurrencyIsoCode)) {
					return;
				}

				Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
				try {
					insert cd;
					cd.put('CurrencyIsoCode', null);
					update cd;

					Id cdId = cd.Id;
					cd = Database.query(
						'SELECT Id, CurrencyIsoCode, Cash_Disbursement_Batch__r.CurrencyIsoCode FROM Cash_Disbursement__c WHERE Id = :cdId'
					);
				} catch (DmlException ex) {
				} catch (QueryException ex) {
				}

				System.assertNotEquals(null, cd);
				System.assertEquals(null, cd.get('CurrencyIsoCode'));
				System.assertEquals(
					cd.getSObject('Cash_Disbursement_Batch__r').get('CurrencyIsoCode'),
					cd.get('CurrencyIsoCode')
				);
				Test.stopTest();
			}
		} catch (Exception ex) {
			//just skip this test if it is non-MC org
		}
	}

	@IsTest
	public static void testValidate1099InfoWhenDisbursementDateLessThan1099EffYear() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			List<Form_Type__mdt> formTypesAll = DomainUtils.getFormTypesByEffectiveYear(2001);
			String form1099TypeId = formTypesAll[0].Id;

			List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(form1099TypeId);
			String form1099BoxId = formCategories[0].Id;

			Cash_Disbursement__c cd = testData.cashDisbursements[0];
			cd.Disbursement_Date__c = Date.newInstance(2020, 1, 1);
			update cd;

			Test.startTest();
			cd.Form_Category_Id__c = form1099BoxId;
			Database.SaveResult result = Database.update(cd, false);
			Test.stopTest();

			System.assertEquals(false, result.isSuccess());
			System.assertEquals(1, result.getErrors().size());
			String expectedMsg = String.format(
				CashDisbursementActions.INVALID_1099_INFO,
				new List<String>{ cd.Disbursement_Date__c.format() }
			);
			System.assertEquals(expectedMsg, result.getErrors()[0].getMessage());
		}
	}

	@IsTest
	public static void testValidate1099InfoWhenDisbursementDateGreaterThan1099EffYear() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			List<Form_Type__mdt> formTypesAll = DomainUtils.getFormTypesByEffectiveYear(2020);
			String form1099TypeId = formTypesAll[0].Id;

			List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(form1099TypeId);
			String form1099BoxId = formCategories[0].Id;

			Cash_Disbursement__c cd = testData.cashDisbursements[0];
			cd.Disbursement_Date__c = Date.newInstance(2019, 1, 1);
			update cd;

			Test.startTest();
			cd.Form_Category_Id__c = form1099BoxId;
			Database.SaveResult result = Database.update(cd, false);
			Test.stopTest();

			System.assertEquals(false, result.isSuccess());
			System.assertEquals(1, result.getErrors().size());
			String expectedMsg = String.format(
				CashDisbursementActions.INVALID_1099_INFO,
				new List<String>{ cd.Disbursement_Date__c.format() }
			);
			System.assertEquals(expectedMsg, result.getErrors()[0].getMessage());
		}
	}

	@IsTest
	public static void testValidate1099InfoWhenValid() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			List<Form_Type__mdt> formTypesAll = DomainUtils.getFormTypesByEffectiveYear(2019);
			String form1099TypeId = formTypesAll[0].Id;

			List<Form_Category__mdt> formCategories = X1099InfoHelper.getFormCategoriesByFormType(form1099TypeId);
			String form1099BoxId = formCategories[0].Id;

			Cash_Disbursement__c cd = testData.cashDisbursements[0];
			cd.Disbursement_Date__c = Date.newInstance(2019, 1, 1);
			update cd;

			Test.startTest();
			cd.Form_Category_Id__c = form1099BoxId;
			update cd;
			Test.stopTest();

			Cash_Disbursement__c updatedCD = [
				SELECT Form_Category_Id__c, Disbursement_Date__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];
			System.assertEquals(updatedCD.Form_Category_Id__c, form1099BoxId);
			System.assertEquals(updatedCD.Disbursement_Date__c, cd.Disbursement_Date__c);
		}
	}

	@IsTest
	public static void testDefaultAsPayTypeNegative() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Account acc = [
				SELECT Id, Enable_Payment_Services__c, AS_Pay_Type__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];
			acc.Enable_Payment_Services__c = false;
			acc.AS_Pay_Type__c = 'Virtual Card';
			update acc;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Disbursement_Date__c = System.today();
			cd.Debit_GL_Account__c = null;
			cd.Amount__c = 5;
			insert cd;

			Cash_Disbursement__c updatedCD = [
				SELECT AS_Pay_Type__c, Vendor__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];
			Assert.areEqual(updatedCD.Vendor__c, acc.Id);
			Assert.areNotEqual(updatedCD.AS_Pay_Type__c, acc.AS_Pay_Type__c);
			Assert.IsNull(updatedCD.AS_Pay_Type__c);
			Test.stopTest();
		}
	}

	@IsTest
	public static void testNoDefaultAsPayTypeNegative() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			SingleRequestMock awsSuccess = new SingleRequestMock(
				200,
				'Complete',
				AwsServiceTest.CREATE_VENDOR_JSON,
				new Map<String, String>{ 'Content-Type' => 'application/json' }
			);
			Test.setMock(HttpCalloutMock.class, awsSuccess);
			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Account acc = [
				SELECT Id, Enable_Payment_Services__c, AS_Pay_Type__c
				FROM Account
				WHERE Name = 'Test Account'
				LIMIT 1
			];
			acc.Enable_Payment_Services__c = true;
			acc.AS_Pay_Type__c = 'Virtual Card';
			update acc;

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.AS_Pay_Type__c = 'ACH';
			cd.Debit_GL_Account__c = null;
			cd.Amount__c = 5;
			insert cd;

			Cash_Disbursement__c updatedCD = [
				SELECT AS_Pay_Type__c, Vendor__c
				FROM Cash_Disbursement__c
				WHERE Id = :cd.Id
				LIMIT 1
			];
			Assert.areEqual(updatedCD.Vendor__c, acc.Id);
			Assert.areNotEqual(updatedCD.AS_Pay_Type__c, acc.AS_Pay_Type__c);
			Assert.areEqual(updatedCD.AS_Pay_Type__c, 'ACH');
			Test.stopTest();
		}
	}

	@IsTest
	public static void testCashDisbursementFieldRestrictOnPaymentFeatureDisable() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches();

		System.runAs(testData.users[1]) {
			Test.startTest();
			try {
				Cash_Disbursement__c disbursement = new Cash_Disbursement__c();
				disbursement.Cash_Disbursement_Batch__c = testData.cashDisbursementBatch[0].Id;
				disbursement.Disbursement_Date__c = System.today();
				disbursement.Type__c = 'Check';
				disbursement.Amount__c = 0;
				disbursement.Source__c = 'Payable';
				disbursement.Bank_Account__c = testData.glAccounts[0].Id;
				disbursement.Debit_GL_Account__c = testData.glAccounts[4].Id;
				disbursement.Accounting_Period__c = testData.acctPeriods[0].Id;
				disbursement.Status__c = AbstractPostHandler.DEFAULT_POSTING_STATUS_NOT_POSTED;
				disbursement.Reference__c = 'the reference 0';
				disbursement.Contact__c = testData.contacts[0].Id;

				insert disbursement;
			} catch (DMLException ex) {
				Assert.isNotNull(ex);
				Assert.isTrue(
					ex.getMessage()
						.contains(
							String.format(
								Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED,
								new List<String>{ getCashDisbursementRestrictFields() }
							)
						)
				);
			}

			Test.stopTest();
		}
	}

	@IsTest
	public static void testCashDisbursementFieldRestrictOnPaymentFeatureEnable() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			Cash_Disbursement__c disbursement = testData.cashDisbursements[0].clone(false, true);
			disbursement.Payment_Service_Status__c = 'Pending';
			disbursement.Debit_GL_Account__c = null;
			disbursement.Amount__c = 5;
			insert disbursement;

			Assert.isNotNull(disbursement);
			Assert.isNotNull(disbursement.Payment_Service_Status__c);
			Test.stopTest();
		}
	}

	@IsTest
	public static void testUpdateCashDiscbursementFieldRestrictOnPaymentFeatureDisable() {
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();

			try {
				testData.cashDisbursements[0].Payment_Service_Status_Note__c = 'Feature not enabled';
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				Assert.isNotNull(ex);
				Assert.areEqual(
					ex.getDMLMessage(0),
					String.format(
						Label.ERR_FIELDS_PAYMENT_SERVICES_FEATURE_DISABLED,
						new List<string>{ getCashDisbursementRestrictFields() }
					)
				);
			}

			Test.stopTest();
		}
	}

	@IsTest
	public static void testUpdateCashDisbursementFieldRestrictOnPaymentFeatureEnable() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);

		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			testData.cashDisbursements[0].Payment_Service_Status_Note__c = 'Feature enabled';
			update testData.cashDisbursements[0];
			Test.stopTest();
		}

		Assert.areEqual(
			'Feature enabled',
			[
				SELECT Payment_Service_Status_Note__c
				FROM Cash_Disbursement__c
				WHERE Id = :testData.cashDisbursements[0].Id
			]
			.Payment_Service_Status_Note__c
		);
	}

	private static String getCashDisbursementRestrictFields() {
		APAutomationControl service = new APAutomationControl();
		return Service.getFieldLabels(Service.getFieldGrants().get(Cash_Disbursement__c.SObjectType));
	}

	@IsTest
	public static void testPaymentServicesValidationRestrictUpdateAfterPosting() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance().createCashDisbursementBatches().createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();

			Accounting_Settings__c accountingSettings = testData.settings;
			accountingSettings.Cash_Disbursement_Source__c = 'Manual';
			update accountingSettings;

			testData.cashDisbursements[0].Payment_Service_Status__c = 'Submitted';
			update testData.cashDisbursements[0];

			try {
				testData.cashDisbursements[0].Type__c = 'Payment Services';
				testData.cashDisbursements[0].Debit_GL_Account__c = null;
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				Assert.isNotNull(ex);
				Assert.areEqual(ex.getDMLMessage(0), Label.ERR_CD_PAYMENT_SERVICES_ALREADY_SUBMITTED);
			} catch (Exception e) {
				Assert.fail('Update should fail resuling in caught DML message');
			}

			try {
				testData.cashDisbursements[0].Disbursement_Date__c = testData.cashDisbursements[0]
					.Disbursement_Date__c.addDays(1);
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				Assert.isNotNull(ex);
				Assert.areEqual(ex.getDMLMessage(0), Label.ERR_CD_PAYMENT_SERVICES_ALREADY_SUBMITTED);
			} catch (Exception e) {
				Assert.fail('Update should fail resuling in caught DML message');
			}

			try {
				testData.cashDisbursements[0].Payee_City__c = 'TestCity';
				testData.cashDisbursements[0].Debit_GL_Account__c = null;
				update testData.cashDisbursements[0];
			} catch (DMLException ex) {
				Assert.isNotNull(ex);
				Assert.areEqual(ex.getDMLMessage(0), Label.ERR_CD_PAYMENT_SERVICES_ALREADY_SUBMITTED);
			} catch (Exception e) {
				Assert.fail('Update should fail resuling in caught DML message');
			}

			Test.stopTest();
		}
	}

	@isTest
	public static void testCashDisbursementStatusUpdate() {
		TestDataSuite testData = TestDataSuite.getInstance()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();

			SingleRequestMock awsSuccess = new SingleRequestMock(
				200,
				'Complete',
				AwsServiceTest.CREATE_PAYMENTS_JSON,
				new Map<String, String>{ 'Content-Type' => 'application/json' }
			);

			Test.setMock(HttpCalloutMock.class, awsSuccess);

			Contact conRec = testData.contacts[0];
			conRec.Email = 'test@test.com';
			update conRec;

			Account accountRec = testData.accounts[0];
			accountRec.Billing_Contact__c = testData.contacts[0].Id;
			update accountRec;

			Ledger__c ledgerRec = testData.ledgers[0];
			ledgerRec.Enrolled_in_Payment_Services__c = true;
			ledgerRec.Payment_Services_Company_Code__c = 'Test101017';
			update ledgerRec;

			Cash_Disbursement__c cd = testData.cashDisbursements[5].clone(false, true);
			cd.Ledger__c = testData.ledgers[0].Id;
			cd.Amount__c = 0;
			cd.Type__c = 'AS Pay';
			insert cd;

			Cash_Disbursement__c insertedCDRecord = [
				SELECT Payment_Status__c
				FROM Cash_Disbursement__c
				WHERE ID = :cd.Id
			];
			System.assertEquals('In Process', String.valueOf(insertedCDRecord.Payment_Status__c));

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ insertedCDRecord });

			List<Cash_Disbursement__c> listOfCDPosted = [
				SELECT Id, Payment_Status__c
				FROM Cash_Disbursement__c
				WHERE Status__c = 'Posted'
			];
			System.assertEquals(1, listOfCDPosted.size());
			System.assertEquals('Pending', listOfCDPosted[0].Payment_Status__c);

			Test.stopTest();
		}
	}

	@isTest
	public static void validateGLBankAccount() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankDisbursements()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			CashDisbursementActions.isBypassGLAccountValidations = true;
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = testData.glAccounts[1].Id;
			cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;

			DmlException dmlEx;
			insert cd;

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

			Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];

			cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			try {
				update cashDis;
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
			.createBankDisbursements()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			CashDisbursementActions.isBypassGLAccountValidations = true;
			try {
				testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
				update testData.bankDisbursements[0];

				Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
				cd.Bank_Account__c = testData.glAccounts[0].Id;
				cd.Disbursement_Date__c = System.today() + 3;
				insert cd;

				AbstractPostHandler postHandler = new CashDisbursementPostHandler();
				List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

				Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];

				cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
				update cashDis;
			} catch (DMLException ex) {
				Assert.isNotNull(ex);
				Assert.isTrue(
					ex.getMessage()
						.contains(Label.ERR_PREVENT_ASSOCIATING_RECORD_IF_DATE_EXCEEDS_DISBURSEMENT_DATE_ON_BD)
				);
			}

			Test.stopTest();
		}
	}

	@isTest
	public static void validateCurrencyFieldIfBankDisAssociated() {
		try {
			FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
			TestDataSuite testData = TestDataSuite.getInstance()
				.enableMultiCurrency()
				.createBankDisbursements()
				.createCashDisbursementBatches()
				.createLedgerWithPaymentEnabled()
				.createCashDisbursements();

			System.runAs(testData.users[1]) {
				Test.startTest();
				CashDisbursementActions.isBypassGLAccountValidations = true;

				String theNewCurrencyIsoCode = SObjectActionsTest.getTheNewCurrencyIsoCode();
				if (String.isBlank(theNewCurrencyIsoCode)) {
					return;
				}

				testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
				testData.bankDisbursements[0].put('CurrencyIsoCode', 'EUR');
				update testData.bankDisbursements[0];

				Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
				cd.Bank_Account__c = testData.glAccounts[0].Id;
				cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
				cd.put('CurrencyIsoCode', 'USD');

				cd.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
				insert cd;

				AbstractPostHandler postHandler = new CashDisbursementPostHandler();
				List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

				Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];

				DmlException dmlEx;
				try {
					update cashDis;
				} catch (DmlException ex) {
					dmlEx = ex;
					Assert.isNotNull(ex);
					Assert.isTrue(ex.getMessage().contains(Label.ERR_CASH_DISBURSEMENT_CURRENCY_MISMATCH_BANK_DISB));
				}
				Test.stopTest();
			}
		} catch (TestDataSuite.TestDataSuiteException ex) {
			ex = ex;
		}
	}

	@isTest
	public static void validateBankDisbFieldForClearedBankRec() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankDisbursements()
			.createBankReconciliations()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			CashDisbursementActions.isBypassGLAccountValidations = true;
			TriggerObserver.getInstance()
				.unlockFields(new Set<Schema.SObjectField>{ Cash_Disbursement__c.Bank_Reconciliation__c });
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = testData.glAccounts[0].Id;
			cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
			insert cd;

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

			Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];

			cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update cashDis;

			cashDis.Bank_Reconciliation__c = testData.bankReconciliations[1].Id;
			update cashDis;

			DMLException dmlEx;
			try {
				cashDis.Bank_Disbursement__c = testData.bankDisbursements[1].Id;
				update cashDis;
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
						Label.COMMON_CASH_DISBURSEMENT,
						bankReconciliationRec.Name,
						Label.COMMON_CASH_DISBURSEMENT
					}
				),
				dmlEx.getDMLMessage(0)
			);
			Test.stopTest();
		}
	}

	@isTest
	public static void validateBankDisbFieldForClearedBankDisbursement() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createBankDisbursements()
			.createBankReconciliations()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			TriggerObserver.getInstance()
				.unlockFields(
					new Set<Schema.SObjectField>{
						Bank_Disbursement__c.Bank_Reconciliation__c,
						Bank_Disbursement__c.Bank_Reconciliation_Date__c
					}
				);

			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			testData.bankDisbursements[0].Bank_Reconciliation__c = testData.bankReconciliations[1].Id;
			update testData.bankDisbursements[0];

			CashDisbursementActions.isBypassGLAccountValidations = true;
			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = testData.glAccounts[0].Id;
			cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
			insert cd;

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

			Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];

			DMLException dmlEx;
			try {
				cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
				update cashDis;
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
			.createBankDisbursements()
			.createBankReconciliations()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			CashDisbursementActions.isBypassGLAccountValidations = true;
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = testData.glAccounts[0].Id;
			cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
			cd.Amount__c = 200;
			insert cd;

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

			Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];

			cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update cashDis;

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
			.createBankDisbursements()
			.createBankReconciliations()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users[1]) {
			Test.startTest();
			CashDisbursementActions.isBypassGLAccountValidations = true;
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			update testData.bankDisbursements[0];

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = testData.glAccounts[0].Id;
			cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
			cd.Amount__c = 200;
			cd.Bank_Account__c = testData.glAccounts[0].Id;
			insert cd;

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			List<PostResult> results = postHandler.post(new List<Cash_Disbursement__c>{ cd });

			Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];
			cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update cashDis;

			Cash_Disbursement__c cd1 = testData.cashDisbursements[0].clone(false, true);
			cd1.Bank_Account__c = testData.glAccounts[0].Id;
			cd1.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
			cd1.Amount__c = 100;
			cd1.Bank_Account__c = testData.glAccounts[0].Id;
			insert cd1;

			AbstractPostHandler postHandler1 = new CashDisbursementPostHandler();
			List<PostResult> results1 = postHandler1.post(new List<Cash_Disbursement__c>{ cd1 });

			Cash_Disbursement__c cashDis1 = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd1.Id];

			cashDis1.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			update cashDis1;

			Bank_Disbursement__c bankDis = [
				SELECT Id, Amount__c, Ledger_Amount__c
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];
			System.assertEquals(300, bankDis.Amount__c);
			System.assertEquals(300, bankDis.Ledger_Amount__c);

			postHandler.dispatcher.clearResultsMap();
			postHandler.unpost(new List<Cash_Disbursement__c>{ cd });

			Cash_Disbursement__c unpostedRec = [SELECT Id FROM Cash_Disbursement__c WHERE Id = :cashDis.Id];

			delete unpostedRec;

			Bank_Disbursement__c updatedbankDis = [
				SELECT Id, Amount__c, Ledger_Amount__c
				FROM Bank_Disbursement__c
				WHERE ID = :testData.bankDisbursements[0].Id
			][0];
			System.assertEquals(100, updatedbankDis.Amount__c);
			System.assertEquals(100, updatedbankDis.Ledger_Amount__c);

			Test.stopTest();
		}
	}

	@isTest
	public static void testPreventBDBAssociationIfDifferentGLV() {
		FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.FP_PAYMENT_SERVICES_ENABLED, true);
		TestDataSuite testData = TestDataSuite.getInstance()
			.createAccountingVariables()
			.createBankDisbursements()
			.createCashDisbursementBatches()
			.createLedgerWithPaymentEnabled()
			.createCashDisbursements();

		System.runAs(testData.users.get(1)) {
			Test.startTest();

			CashDisbursementActions.isBypassGLAccountValidations = true;
			testData.bankDisbursements[0].Bank_GL_Account__c = testData.glAccounts[0].Id;
			testData.bankDisbursements[0].GL_Account_Variable_1__c = testData.accountingVariables1[1].Id;
			update testData.bankDisbursements[0];

			Cash_Disbursement__c cd = testData.cashDisbursements[0].clone(false, true);
			cd.Bank_Account__c = testData.glAccounts[0].Id;
			cd.Disbursement_Date__c = testData.acctPeriods[1].Start_Date__c;
			cd.GL_Account_Variable_1__c = testData.accountingVariables1[0].Id;
			DmlException dmlEx;
			insert cd;

			AbstractPostHandler postHandler = new CashDisbursementPostHandler();
			postHandler.post(new List<Cash_Disbursement__c>{ cd });

            Cash_Disbursement__c cashDis = [SELECT ID, Status__c FROM Cash_Disbursement__c WHERE Id = :cd.Id];
			cashDis.Bank_Disbursement__c = testData.bankDisbursements[0].Id;
			
			try {
				update cashDis;
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
					CashDisbursementActions.CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);

            postHandler.dispatcher.clearResultsMap();
            postHandler.unpost(new List<Cash_Disbursement__c>{ cashDis });

            testData.bankDisbursements[0].GL_Account_Variable_1__c = null;
            testData.bankDisbursements[0].GL_Account_Variable_2__c = testData.accountingVariables2[0].Id;
            update testData.bankDisbursements[0];

            

            cashDis.GL_Account_Variable_2__c = testData.accountingVariables2[1].Id;

            postHandler.post(new List<Cash_Disbursement__c>{ cashDis });
            try {
				update cashDis;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(
				String.format(
					CashDisbursementActions.CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);


            postHandler.dispatcher.clearResultsMap();
            postHandler.unpost(new List<Cash_Disbursement__c>{ cashDis });

            testData.bankDisbursements[0].GL_Account_Variable_2__c = null;
            testData.bankDisbursements[0].GL_Account_Variable_3__c = testData.accountingVariables3[0].Id;
            update testData.bankDisbursements[0];

            cashDis.GL_Account_Variable_3__c = testData.accountingVariables3[1].Id;

            postHandler.post(new List<Cash_Disbursement__c>{ cashDis });
            try {
				update cashDis;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(
				String.format(
					CashDisbursementActions.CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);

            postHandler.dispatcher.clearResultsMap();
            postHandler.unpost(new List<Cash_Disbursement__c>{ cashDis });

            testData.bankDisbursements[0].GL_Account_Variable_3__c = null;
            testData.bankDisbursements[0].GL_Account_Variable_4__c = testData.accountingVariables4[0].Id;
            update testData.bankDisbursements[0];

            

            cashDis.GL_Account_Variable_4__c = testData.accountingVariables4[1].Id;

            postHandler.post(new List<Cash_Disbursement__c>{ cashDis });
            try {
				update cashDis;
			} catch (DMLException ex) {
				dmlEx = ex;
			}
			System.assertEquals(
				String.format(
					CashDisbursementActions.CASH_DISBURSEMENT_CANT_BE_ASSOCIATED_TO_BDB_IF_DIFFERENT_GLV,
					new List<String>{ bankDisbursement.Name }
				),
				dmlEx.getDMLMessage(0)
			);

           
		}
	}
}
