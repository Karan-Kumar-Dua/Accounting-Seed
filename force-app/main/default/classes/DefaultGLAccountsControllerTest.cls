@IsTest
private class DefaultGLAccountsControllerTest {

    @TestSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @IsTest
    static void testBehavior() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, Object> result = DefaultGLAccountsController.fetchSettings();
            System.assert(result.get('ledgerOptions') != null);
            System.assert(result.get('defaultWrapsByLedgerIds') != null);
            System.assert(result.get('specWrapsByTypes') != null);

            Map<String, Object> saveResult = DefaultGLAccountsController.saveDetails(new List<Map<String, Object>>{
                new Map<String, Object>{
                    'specDevName' => 'Currency_Gain_Loss_GL_Account',
                    'glAccountId' => testData.glAccounts[0].Id,
                    'uniqueKey' => String.join(new List<String>{
                        'Currency_Gain_Loss_GL_Account', testData.ledgers[0].Id
                    }, ':')
                }
            }, testData.ledgers[0].Id);
            System.assert(((List<Object>) saveResult.get('errors')).isEmpty());

            Map<String, Object> deleteResult = DefaultGLAccountsController.saveDetails(new List<Map<String, Object>>{
                new Map<String, Object>{
                    'specDevName' => 'Currency_Gain_Loss_GL_Account',
                    'glAccountId' => null,
                    'uniqueKey' => String.join(new List<String>{
                        'Currency_Gain_Loss_GL_Account', testData.ledgers[0].Id
                    }, ':')
                }
            }, testData.ledgers[0].Id);
            System.assert(((List<Object>) deleteResult.get('errors')).isEmpty());
            Test.stopTest();
        }
    }

    @IsTest
    static void testFSProductCostRequiredDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, Object> result = DefaultGLAccountsController.fetchSettings();
            for (String led : result.keySet()) {
                if (led == 'specWrapsByTypes') {
                    for (Object def : ((Map<String, Object>) result.get(led)).values()) {
                        for (Map<String, Object> spec : ((List<Map<String, Object>>) def)) {
                            if (spec.get('devName') == GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT) {
                                System.assert(!(Boolean) spec.get('required'));
                            }
                            if (spec.get('devName') == GLAccountDefaultsHandler.WORK_IN_PROCESS_GL_ACCOUNT) {
                                System.assert(!(Boolean) spec.get('required'));
                            }
                            if (spec.get('devName') == GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT) {
                                System.assert(!(Boolean) spec.get('required'));
                            }
                        }
                    }

                }
            }
        }
    }

    @IsTest
    static void testERPAverageCostRequiredDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled().setInventoryValuationAverageCost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, Object> result = DefaultGLAccountsController.fetchSettings();
            for (String led : result.keySet()) {
                if (led == 'specWrapsByTypes') {
                    for (Object def : ((Map<String, Object>) result.get(led)).values()) {
                        for (Map<String, Object> spec : ((List<Map<String, Object>>) def)) {
                            if (spec.get('devName') == GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT) {
                                System.assert((Boolean) spec.get('required'));
                            }
                            if (spec.get('devName') == GLAccountDefaultsHandler.WORK_IN_PROCESS_GL_ACCOUNT) {
                                System.assert((Boolean) spec.get('required'));
                            }
                            if (spec.get('devName') == GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT) {
                                System.assert(!(Boolean) spec.get('required'));
                            }
                        }
                    }

                }
            }
        }
    }

    @IsTest
    static void testERPStandardCostRequiredDefaults() {
        TestDataSuite testData = TestDataSuite.getInstance().setERPEnabled().setInventoryValuationStandardCost();

        System.runAs(testData.users[1]) {
            Test.startTest();
            Map<String, Object> result = DefaultGLAccountsController.fetchSettings();
            for (String led : result.keySet()) {
                if (led == 'specWrapsByTypes') {
                    for (Object def : ((Map<String, Object>) result.get(led)).values()) {
                        for (Map<String, Object> spec : ((List<Map<String, Object>>) def)) {
                            if (spec.get('devName') == GLAccountDefaultsHandler.VOUCHERS_PAYABLE_GL_ACCOUNT) {
                                System.assert((Boolean) spec.get('required'));
                            }
                            if (spec.get('devName') == GLAccountDefaultsHandler.WORK_IN_PROCESS_GL_ACCOUNT) {
                                System.assert((Boolean) spec.get('required'));
                            }
                            if (spec.get('devName') == GLAccountDefaultsHandler.INVENTORY_VARIANCE_GL_ACCOUNT) {
                                System.assert((Boolean) spec.get('required'));
                            }
                        }
                    }

                }
            }
        }
    }

}