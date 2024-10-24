@isTest
public with sharing class LedgerHierarchyModelTest {
    
    private static Ledger_Hierarchy__c getFakeLedgerHierarchy() {
        return new Ledger_Hierarchy__c(Id = FinancialSuiteUtils.getFakeId(Ledger_Hierarchy__c.SObjectType));
    }

    @testSetup
    private static void setupTestData() {
        TestDataSuite.getInstance(true);
    }

    @isTest
    private static void testHasChildren() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            LedgerHierarchyModel model = new LedgerHierarchyModel(testData.ledgerHierarchies[0]);
            System.assert(!model.hasChildren());

            model.children = new List<LedgerHierarchyModel>();
            System.assert(!model.hasChildren());

            model.children.add(new LedgerHierarchyModel(testData.ledgerHierarchies[2]));
            System.assert(model.hasChildren());
        }
    }

    @isTest
    private static void testGetIteratorLeaf() {
        TestDataSuite testData = TestDataSuite.getInstance()
            .createConsolidationLedgers()
            .createLedgerHierarchies();

        System.runAs(testData.users.get(1)) {
            LedgerHierarchyModel model = new LedgerHierarchyModel(testData.ledgerHierarchies[0]);
            LedgerHierarchyModel.Iterator itr = model.getIterator();
            System.assert(itr.hasNext());
            System.assertEquals(model.value.Id, itr.next().value.Id);
            System.assert(!itr.hasNext());
            System.assertEquals(null, itr.next());
        }
    }

    @isTest
    private static void testGetIteratorNode() {
        TestDataSuite testData = TestDataSuite.getInstance();

        System.runAs(testData.users.get(1)) {
            LedgerHierarchyModel A = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel B = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel C = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel D = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel E = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel F = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel G = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel H = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel I = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel J = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel K = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel L = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel M = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel N = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel O = new LedgerHierarchyModel(getFakeLedgerHierarchy());
            LedgerHierarchyModel P = new LedgerHierarchyModel(getFakeLedgerHierarchy());
        
            A.children = new List<LedgerHierarchyModel>{ B, C, D };
            B.children = new List<LedgerHierarchyModel>{ I, J, K };
            D.children = new List<LedgerHierarchyModel>{ E, F, G };
            G.children = new List<LedgerHierarchyModel>{ H };
            J.children = new List<LedgerHierarchyModel>{ L, M, N };
            K.children = new List<LedgerHierarchyModel>{ O, P };

            List<LedgerHierarchyModel> actual = new List<LedgerHierarchyModel>();
            List<LedgerHierarchyModel> expected = new List<LedgerHierarchyModel>{ J, K, B, G, D, A };

            LedgerHierarchyModel.Iterator itr = A.getIterator();
            while(itr.hasNext()) {
                actual.add(itr.next());
            }

            System.assertEquals(expected.size(), actual.size());
            for (Integer z=0;z<actual.size();z++) {
                System.assertEquals(expected[z].value.Id, actual[z].value.Id);
            }
        }
    }

}