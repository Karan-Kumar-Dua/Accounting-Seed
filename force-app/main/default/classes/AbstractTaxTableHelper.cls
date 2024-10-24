public with sharing abstract class AbstractTaxTableHelper {
    //List wrappers is used on VF pages
    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;
    public transient List<TaxDataWrapper> taxTableData { get; set; }
    public Integer ldvCalcTaxLineLimit = 4000;

    protected void getTableData(List<Account_Tax__c> taxes, List<SObject> taxableLines) {
        taxTableData = new List<TaxDataWrapper>();
        TaxDataWrapper table;
        for (Account_Tax__c tax : taxes) {
            String taxRateName = tax.Tax_Rate__r.Name;
            Decimal taxRate = tax.Tax_Rate__r.Tax_Rate__c;
            Id taxRateId = tax.Tax_Rate__r.Id;
            table = new TaxDataWrapper(taxRateName, taxRateId, taxRate, taxableLines);
            taxTableData.add(table);
        }
    }

    //wrapper class for Tax table
    public with sharing class TaxDataWrapper {
        public String taxRateName { get; set; }
        public Id taxRateId { get; set; }
        public String taxTotalName { get; set; }
        public Decimal taxRate { get; set; }
        public Map<Id, Map<Id, String>> taxableProducts { get; set; }
        public Map<Id, String> linesNames { get; set; }
        public Map<Id, Decimal> amount { get; set; }
        public Map<Id, Decimal> taxAmount { get; set; }
        public Boolean isTotalsRow { get; set; }
        public Decimal taxAmountTotal { get; set; }
        // line row constructor
        public TaxDataWrapper(String tRName, Id tRId, Decimal tR, List<SObject> lines) {
            taxRateName = tRName;
            taxRateId = tRId;
            taxRate = tR;
            taxableProducts = new Map<Id, Map<Id, String>>();
            linesNames= new Map<Id, String>();
            amount = new Map<Id, Decimal>();
            taxAmount = new Map<Id, Decimal>();
            isTotalsRow = false;
            getData(lines);
            getSummaryData(lines);
        }

        private void getData(List<SObject> lines) {
            String totalFieldName = getTotalFieldName(lines.getSObjectType());
            for (SObject line : lines) {
                Decimal lineTax = (taxRate/100 * (Decimal) line.get(totalFieldName));
                taxableProducts.put(line.Id, new Map<Id, String>{getProduct(line).Id => getProduct(line).Name});
                linesNames.put(line.Id, (String) line.get('Name'));
                amount.put(line.Id, (Decimal) line.get(totalFieldName));
                taxAmount.put(line.Id, lineTax);
            }
        }

        private void getSummaryData(List<SObject> lines) {
            Decimal count = 0;
            String totalFieldName = getTotalFieldName(lines.getSObjectType());
            for (SObject line : lines) {
                Decimal lineTax = (taxRate/100 * (Decimal) line.get(totalFieldName));
                count += lineTax;
            }
            taxTotalName = Label.COMMON_TOTAL + ' ' + taxRateName + ' ' +  Label.COMMON_AMOUNT + ':';
            taxAmountTotal = count.setScale(2, System.RoundingMode.HALF_UP);

        }
        // return "Total" field name according SObject type
        private String getTotalFieldName (SObjectType soType) {
            String fieldName = '';
            if (soType == Billing_Line__c.SObjectType) {
                fieldName = PACKAGE_QUALIFIER + 'Total__c';
            } else if (soType == Account_Payable_Line__c.SObjectType) {
                fieldName = PACKAGE_QUALIFIER + 'Amount__c';
            }
            else if (soType == OpportunityLineItem.SObjectType) {
                fieldName = 'TotalPrice';
            }
            return fieldName;
        }

        private Product2 getProduct(SObject line) {
            Product2 product;
            if (line.getSObjectType() == OpportunityLineItem.SObjectType) {
                product = (Product2) line.getSObject('PriceBookEntry').getSObject('Product2');
            }
            else {
                product = (Product2) line.getSObject('Product__r');
            }
            return product;
        }
    }
}