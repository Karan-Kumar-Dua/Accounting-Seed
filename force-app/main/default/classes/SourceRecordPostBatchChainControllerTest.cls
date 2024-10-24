@IsTest
private class SourceRecordPostBatchChainControllerTest {

    @IsTest
    private static void testGetScheduledJobName() {
        List<String> sourceRecordTypesAsString = new List<String>{
            'Amortization Entries',
            'Cash Disbursements',
            'Inbound Order Inventory Movements (IIM)',
            'Outbound Inventory Movements (OIM)',
            'Purchase Order Inventory Movements (PIM)',
            'Sales Order Inventory Movements (SIM)',
            'Manufacturing Inventory Movements (MIM)'
        };
        SourceRecordPostBatchChainController chainController = new SourceRecordPostBatchChainController(sourceRecordTypesAsString);
        Test.startTest();
        String jobName = chainController.getScheduledJobName();
        System.assertEquals('Scheduled Post: Amortization Entries, Cash Disbursements, IIM, OIM, PIM, SIM, MIM', jobName);
    }

    @IsTest
    private static void testGetLDVTypesList() {
        FeatureManagement.setPackageBooleanValue(FeatureManagementHandler.LARGE_DATA_VOLUME_MODE, true);
        List<String> sourceRecordTypesAsString = new List<String>{
            'Billings',
            'Amortization Entries',
            'Cash Disbursements'
        };
        SourceRecordPostBatchChainController chainController = new SourceRecordPostBatchChainController(sourceRecordTypesAsString);
        Test.startTest();
        List<AbstractSourceRecordPostBatch.SourceRecordType> result = new List<AbstractSourceRecordPostBatch.SourceRecordType> {
            AbstractSourceRecordPostBatch.SourceRecordType.BILLING
        };
        System.assert(chainController.hasLDVTypes());
        System.assertEquals(result, chainController.currentLdv());
    }

}