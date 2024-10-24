public with sharing class SourceRecordPostBatchChainController implements Iterator<AbstractSourceRecordPostBatch.SourceRecordType> {

    private List<String> sourceRecordTypesAsString;
    private List<AbstractSourceRecordPostBatch.SourceRecordType> sourceRecordTypes;
    private List<AbstractSourceRecordPostBatch.SourceRecordType> ldvSourceRecordTypes;
    private Integer currentIndex;
    private Map<AbstractSourceRecordPostBatch.SourceRecordType, SObjectType> sobjectTypesMap;
    private static final List<AbstractSourceRecordPostBatch.SourceRecordType> ldvSobjectTypes = new List<AbstractSourceRecordPostBatch.SourceRecordType> {
        AbstractSourceRecordPostBatch.SourceRecordType.BILLING,
        AbstractSourceRecordPostBatch.SourceRecordType.PAYABLE,
        AbstractSourceRecordPostBatch.SourceRecordType.JOURNAL_ENTRY,
        AbstractSourceRecordPostBatch.SourceRecordType.BILLING_CASH_RECEIPT,
        AbstractSourceRecordPostBatch.SourceRecordType.AP_DISBURSEMENT
    };
    private Id ajrId;

    public SourceRecordPostBatchChainController(List<String> sourceRecordTypesAsString) {
        this.sourceRecordTypesAsString = sourceRecordTypesAsString;
        this.currentIndex = 0;
        this.ldvSourceRecordTypes = new List<AbstractSourceRecordPostBatch.SourceRecordType>();
        init();
        if (AccountingSettingsHandler.isERPEnabled()) {
            moveERPTypesToEndOfList();
        }
        if (FeatureManagementHandler.isLargeDataVolumeModeEnabled()) {
            selectLDVTypes();
        }
    }

    public void setAJR(String jobName) {
        if (this.ajrId == null) {
            AutomatedJobResultsHandler.setJobType(jobName);
            this.ajrId = AutomatedJobResultsHandler.saveAutomatedJobResults();
        }
    }

    public Id getAjrId() {
        return ajrId;
    }

    public Boolean hasNext() {
        return currentIndex < sourceRecordTypes.size() - 1;
    }

    public AbstractSourceRecordPostBatch.SourceRecordType next() {
        if (hasNext()) {
            currentIndex++;
            return sourceRecordTypes[currentIndex];
        } else {
            throw new NoSuchElementException();
        }
    }

    public AbstractSourceRecordPostBatch.SourceRecordType current() {
        if (currentIndex <= sourceRecordTypes.size() - 1) {
            return sourceRecordTypes[currentIndex];
        } else {
            throw new NoSuchElementException();
        }
    }

    public List<AbstractSourceRecordPostBatch.SourceRecordType> currentLdv() {
        return ldvSourceRecordTypes;
    }

    public Boolean hasLDVTypes() {
        return !ldvSourceRecordTypes.isEmpty();
    }

    public void clearLDVTypes() {
        ldvSourceRecordTypes.clear();
    }

    private void selectLDVTypes() {
        List<AbstractSourceRecordPostBatch.SourceRecordType> fsTypes = new List<AbstractSourceRecordPostBatch.SourceRecordType>();
        for (AbstractSourceRecordPostBatch.SourceRecordType srType : sourceRecordTypes) {
            if (ldvSobjectTypes.contains(srType)) {
                ldvSourceRecordTypes.add(srType);
            } else {
                fsTypes.add(srType);
            }
        }
        this.sourceRecordTypes.clear();
        this.sourceRecordTypes.addAll(fsTypes);
    }

    private void moveERPTypesToEndOfList() {
        List<AbstractSourceRecordPostBatch.SourceRecordType> fsTypes = new List<AbstractSourceRecordPostBatch.SourceRecordType>();
        List<AbstractSourceRecordPostBatch.SourceRecordType> erpTypes = new List<AbstractSourceRecordPostBatch.SourceRecordType>();
        for (AbstractSourceRecordPostBatch.SourceRecordType srType : sourceRecordTypes) {
            if (isERPType(srType)) {
                erpTypes.add(srType);
            }
            else {
                fsTypes.add(srType);
            }
        }
        this.sourceRecordTypes.clear();
        this.sourceRecordTypes.addAll(fsTypes);
        this.sourceRecordTypes.addAll(erpTypes);
    }

    public List<AbstractSourceRecordPostBatch.SourceRecordType> getERPTypes() {
        List<AbstractSourceRecordPostBatch.SourceRecordType> result = new List<AbstractSourceRecordPostBatch.SourceRecordType>();
        for (AbstractSourceRecordPostBatch.SourceRecordType srType : sourceRecordTypes) {
            if (isERPType(srType)) {
                result.add(srType);
            }
        }
        return result;
    }

    public Boolean isERPType(AbstractSourceRecordPostBatch.SourceRecordType srType) {
        Boolean result = false;
        if (srType == AbstractSourceRecordPostBatch.SourceRecordType.IIM
                || srType == AbstractSourceRecordPostBatch.SourceRecordType.OIM
                || srType == AbstractSourceRecordPostBatch.SourceRecordType.PIM
                || srType == AbstractSourceRecordPostBatch.SourceRecordType.SIM
                || srType == AbstractSourceRecordPostBatch.SourceRecordType.MIM) {

            result = true;
        }
        return result;
    }

    public String getScheduledJobName() {
        String result = 'Scheduled Post: ' + String.join(sourceRecordTypesAsString, ', ').trim();
        result = result.replace('Inbound Order Inventory Movements (IIM)', 'IIM');
        result = result.replace('Manufacturing Inventory Movements (MIM)', 'MIM');
        result = result.replace('Outbound Inventory Movements (OIM)', 'OIM');
        result = result.replace('Purchase Order Inventory Movements (PIM)', 'PIM');
        result = result.replace('Sales Order Inventory Movements (SIM)', 'SIM');
        return result;
    }

    public SObjectType getCurrentSobjectType() {
        return this.sobjectTypesMap.get(current());
    }

    private void init() {
        this.sourceRecordTypes = new List<AbstractSourceRecordPostBatch.SourceRecordType>();
        this.sobjectTypesMap = new Map<AbstractSourceRecordPostBatch.SourceRecordType, SObjectType>();
        for (String sourceRecordTypeAsString : sourceRecordTypesAsString) {
            switch on sourceRecordTypeAsString {
                when 'Amortization Entries' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.AMORTIZATION);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.AMORTIZATION, Scheduled_Revenue_Expense__c.SobjectType);
                }
                when 'AP Disbursements' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.AP_DISBURSEMENT);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.AP_DISBURSEMENT, AP_Disbursement__c.SobjectType);
                }
                when 'Billings' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.BILLING);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.BILLING, Billing__c.SobjectType);
                }
                when 'Billing Cash Receipts' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.BILLING_CASH_RECEIPT);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.BILLING_CASH_RECEIPT, Billing_Cash_Receipt__c.SobjectType);
                }
                when 'Cash Disbursements' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.CASH_DISBURSEMENT);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.CASH_DISBURSEMENT, Cash_Disbursement__c.SobjectType);
                }
                when 'Cash Receipts' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.CASH_RECEIPT);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.CASH_RECEIPT, Cash_Receipt__c.SobjectType);
                }
                when 'Journal Entries' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.JOURNAL_ENTRY);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.JOURNAL_ENTRY, Journal_Entry__c.SobjectType);
                }
                when 'Payables' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.PAYABLE);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.PAYABLE, Account_Payable__c.SobjectType);
                }
                when 'Time Cards' {
                    this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.TIME_CARD);
                    this.sobjectTypesMap.put(AbstractSourceRecordPostBatch.SourceRecordType.TIME_CARD, Time_Card__c.SobjectType);
                }
                when 'Inbound Order Inventory Movements (IIM)' {
                    if (AccountingSettingsHandler.isERPEnabled()) {
                        this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.IIM);
                    }
                }
                when 'Manufacturing Inventory Movements (MIM)' {
                    if (AccountingSettingsHandler.isERPEnabled()) {
                        this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.MIM);
                    }
                }
                when 'Outbound Inventory Movements (OIM)' {
                    if (AccountingSettingsHandler.isERPEnabled()) {
                        this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.OIM);
                    }
                }
                when 'Purchase Order Inventory Movements (PIM)' {
                    if (AccountingSettingsHandler.isERPEnabled()) {
                        this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.PIM);
                    }
                }
                when 'Sales Order Inventory Movements (SIM)' {
                    if (AccountingSettingsHandler.isERPEnabled()) {
                        this.sourceRecordTypes.add(AbstractSourceRecordPostBatch.SourceRecordType.SIM);
                    }
                }
            }
        }
    }

}