@IsTest
public class BalanceBuilderTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    public static void testCubeBuilderPeriodBalance() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BalanceBuilder builder = new BalanceBuilder();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables[0];

            String hashCode =
                String.valueOf(testData.acctPeriods[0].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c) +
                    'Period' + String.valueOf(testData.glAccounts[16].Id) +
                    'nullnullnullnull';

            System.assertEquals(
                0,
                [SELECT count() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode]
            );

            AccountPayablePostTransaction apt = new AccountPayablePostTransaction(
                new ApexPages.StandardController(testData.payables[0])
            );
            apt.post();

            builder.addCube([
                SELECT  Id,
                        Name,
                        Cube_Type__c,
                        Accounting_Period__r.Name,
                        Accounting_Period__c,
                        GL_Account__c,
                        Opening_Balance__c,
                        GL_Account__r.Name,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Year__c,
                        Current_Period__c,
                        Ledger__c,
                        Year_To_Date__c,
                        Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode
            ]);

            System.assertEquals(
                [SELECT Total__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Total__c,
                builder.getPeriodBalance(
                    testData.acctPeriods[0].Name,
                    String.valueOf(testData.settings.Default_Ledger__c),
                    String.valueOf(testData.glAccounts[16].Id),
                    NULL, NULL, NULL, NULL
                )
            );
        }

    }

    @IsTest
    public static void testCubeBuilderPeriodBalanceForGroup() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createPayables(false);
        Test.startTest();
        testData.createBillings(false);

        System.runAs(testData.users[1]) {
            BalanceBuilder builder = new BalanceBuilder();
            testData.payables[0].Status__c = 'Approved';
            update testData.payables[0];
            String hashCode =
                String.valueOf(testData.acctPeriods[0].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c) +
                    'Period' +
                    String.valueOf(testData.glAccounts[16].Id) +
                    'nullnullnullnull';
            System.assertEquals(0, [SELECT count() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode]);

            AccountPayablePostTransaction apt = new AccountPayablePostTransaction(
                new ApexPages.StandardController(testData.payables[0])
            );
            apt.post();

            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            String hashCode1 =
                String.valueOf(testData.acctPeriods[0].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c) +
                    'Period' +
                    String.valueOf(testData.glAccounts[10].Id) +
                    'nullnullnullnull';
            System.assertEquals(0, [SELECT count() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode1]);

            BillingPostTransaction bpt = new BillingPostTransaction(new ApexPages.StandardController(testData.billings[0]));
            bpt.post();

            Decimal total = [
                SELECT Total__c
                FROM Account_Payable__c
                WHERE Id = :testData.payables[0].Id
            ].Total__c - [
                SELECT Total__c
                FROM Billing__c
                WHERE Id = :testData.billings[0].Id
            ].Total__c;

            List<String> glAccounts = new List<String>();
            glAccounts.add(testData.glAccounts[10].Id);
            glAccounts.add(testData.glAccounts[16].Id);
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);

            builder.addCube([
                SELECT  Id, Name, Cube_Type__c, Accounting_Period__r.Name,
                        Accounting_Period__c, GL_Account__c, Opening_Balance__c,
                        GL_Account__r.Name, GL_Account_Variable_1__c, GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Year__c, Current_Period__c, Ledger__c, Year_To_Date__c, Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode
            ]);

            builder.addCube([
                SELECT  Id, Name, Cube_Type__c, Accounting_Period__r.Name, Accounting_Period__c,
                        GL_Account__c, Opening_Balance__c,
                        GL_Account__r.Name, GL_Account_Variable_1__c, GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Year__c, Current_Period__c, Ledger__c, Year_To_Date__c, Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode1
            ]);

            System.assertEquals(
                total,
                builder.getPeriodBalanceForGroup(
                    testData.acctPeriods[0].Name,
                    String.valueOf(testData.settings.Default_Ledger__c),
                    glAccounts,
                    NULL, NULL, NULL, NULL
                )
            );
        }

    }

    @IsTest
    public static void testCubeBuilderYTDBalance() {
        TestDataSuite testData = TestDataSuite.getInstance().createPayables();

        System.runAs(testData.users[1]) {
            Test.startTest();
            BalanceBuilder builder = new BalanceBuilder();

            testData.payables[0].Status__c = 'Approved';
            testData.payables[3].Status__c = 'Approved';
            update testData.payables;

            String hashCode =
                String.valueOf(testData.acctPeriods[0].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c) +
                    'Period' +
                    String.valueOf(testData.glAccounts[16].Id) +
                    'nullnullnullnull';

            System.assertEquals(
                0,
                [SELECT count() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode]
            );

            AccountPayablePostTransaction apt = new AccountPayablePostTransaction(
                new ApexPages.StandardController(testData.payables[0])
            );
            apt.post();

            String hashCode1 =
                String.valueOf(testData.acctPeriods[1].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c) +
                    'Period' +
                    String.valueOf(testData.glAccounts[16].Id) +
                    'nullnullnullnull';

            apt = new AccountPayablePostTransaction(new ApexPages.StandardController(testData.payables[3]));
            apt.post();

            Financial_Cube__c fc = [
                SELECT  Id, Name, Cube_Type__c, Accounting_Period__r.Name, Accounting_Period__c,
                        GL_Account__c, Opening_Balance__c,
                        GL_Account__r.Name, GL_Account_Variable_1__c, GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Year__c, Current_Period__c, Ledger__c, Year_To_Date__c, Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode
            ];

            FinancialCubeActions.isPreventOverride = true;
            fc.Opening_Balance__c = 1000;
            update fc;
            FinancialCubeActions.isPreventOverride = false;

            builder.addCube([
                SELECT  Id, Name, Cube_Type__c, Accounting_Period__r.Name, Accounting_Period__c,
                        GL_Account__c, Opening_Balance__c,
                        GL_Account__r.Name, GL_Account_Variable_1__c, GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c, GL_Account_Variable_4__c,
                        Year__c, Current_Period__c, Ledger__c, Year_To_Date__c, Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode
            ]);

            builder.addCube([
                SELECT  Id, Name, Cube_Type__c, Accounting_Period__r.Name,
                        Accounting_Period__c, GL_Account__c, Opening_Balance__c,
                        GL_Account__r.Name, GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c, GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c, Year__c, Current_Period__c, Ledger__c, Year_To_Date__c, Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode1
            ]);

            System.assertEquals(
                1000 + [SELECT Total__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Total__c,
                builder.getYTDBalance(
                    testData.acctPeriods[0].Name,
                    String.valueOf(testData.settings.Default_Ledger__c),
                    String.valueOf(testData.glAccounts[16].Id),
                    NULL, NULL, NULL, NULL
                )
            );
        }

    }    

    @IsTest
    public static void testCubeBuilderYTDBalanceForGroup() {
        TestDataSuite testData = TestDataSuite.getInstance();
        testData.createPayables(false);
        Test.startTest();
        testData.createBillings(false);

        System.runAs(testData.users[1]) {
            BalanceBuilder builder = new BalanceBuilder();

            testData.payables[0].Status__c = 'Approved';
            update testData.payables[0];
            String hashCode =
                String.valueOf(testData.acctPeriods[0].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c)  +
                    'Period' +
                    String.valueOf(testData.glAccounts[16].Id) +
                    'nullnullnullnull';

            System.assertEquals(0, [SELECT count() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode]);

            AccountPayablePostTransaction apt = new AccountPayablePostTransaction(new ApexPages.StandardController(testData.payables[0]));
            apt.post();
            System.assertEquals('Posted', [SELECT Status__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id].Status__c);

            testData.billings[0].Status__c = 'Approved';
            update testData.billings[0];
            String hashCode1 =
                String.valueOf(testData.acctPeriods[0].Id) +
                    String.valueOf(testData.settings.Default_Ledger__c)  +
                    'Period' +
                    String.valueOf(testData.glAccounts[10].Id) +
                    'nullnullnullnull';

            System.assertEquals(0, [SELECT count() FROM Financial_Cube_Transaction__c WHERE Financial_Cube__r.Key__c = :hashCode1]);

            BillingPostTransaction bpt = new BillingPostTransaction(new ApexPages.StandardController(testData.billings[0]));
            bpt.post();
            System.assertEquals('Posted', [SELECT Status__c FROM Billing__c WHERE Id = :testData.billings[0].Id].Status__c);

            Decimal total =
                2100 + [
                    SELECT Total__c FROM Account_Payable__c WHERE Id = :testData.payables[0].Id
                ].Total__c + [
                    SELECT Total__c FROM Billing__c WHERE Id = :testData.billings[0].Id
                ].Total__c;

            List<String> glAccounts = new List<String>();
            glAccounts.add(testData.glAccounts[10].Id);
            glAccounts.add(testData.glAccounts[16].Id);

            Financial_Cube__c fc = [
                SELECT  Id,
                        Name,
                        Cube_Type__c,
                        Accounting_Period__r.Name,
                        Accounting_Period__c,
                        GL_Account__c,
                        Opening_Balance__c,
                        GL_Account__r.Name,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Year__c,
                        Current_Period__c,
                        Ledger__c,
                        Year_To_Date__c,
                        Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode
            ];

            fc.Opening_Balance__c = 1000;
            FinancialCubeActions.isPreventOverride = true;
            update fc;
            FinancialCubeActions.isPreventOverride = false;

            builder.addCube([
                SELECT  Id,
                        Name,
                        Cube_Type__c,
                        Accounting_Period__r.Name,
                        Accounting_Period__c,
                        GL_Account__c,
                        Opening_Balance__c,
                        GL_Account__r.Name,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Year__c,
                        Current_Period__c,
                        Ledger__c,
                        Year_To_Date__c,
                        Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode
            ]);


            fc = [
                SELECT  Id,
                        Name,
                        Cube_Type__c,
                        Accounting_Period__r.Name,
                        Accounting_Period__c,
                        GL_Account__c,
                        Opening_Balance__c,
                        GL_Account__r.Name,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Year__c,
                        Current_Period__c,
                        Ledger__c,
                        Year_To_Date__c,
                        Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode1
            ];

            fc.Opening_Balance__c = 2000;
            FinancialCubeActions.isPreventOverride = true;
            update fc;
            FinancialCubeActions.isPreventOverride = false;

            builder.addCube([
                SELECT  Id,
                        Name,
                        Cube_Type__c,
                        Accounting_Period__r.Name,
                        Accounting_Period__c,
                        GL_Account__c,
                        Opening_Balance__c,
                        GL_Account__r.Name,
                        GL_Account_Variable_1__c,
                        GL_Account_Variable_2__c,
                        GL_Account_Variable_3__c,
                        GL_Account_Variable_4__c,
                        Year__c,
                        Current_Period__c,
                        Ledger__c,
                        Year_To_Date__c,
                        Transaction_Amount__c
                FROM Financial_Cube__c
                WHERE Key__c = :hashCode1
            ]);

            System.assertEquals(
                total,
                builder.getYTDBalanceForGroup(
                    testData.acctPeriods[0].Name,
                    String.valueOf(testData.settings.Default_Ledger__c),
                    glAccounts,
                    NULL, NULL, NULL, NULL
                )
            );
        }
    }    
    
}