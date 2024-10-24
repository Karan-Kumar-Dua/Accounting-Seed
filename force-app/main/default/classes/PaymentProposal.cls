public with sharing class PaymentProposal {
    
    public class PaymentProposalException extends Exception {}
    public class PaymentProposalAdvanceSearchException extends Exception {}
    public class PaymentProposalFilterException extends Exception {}

    private static final String PACKAGE_QUALIFIER = GlobalVariables.PACKAGE_QUALIFIER;

    public static Map<String, String>  mapOfFieldNameWithAPIName= new Map<String, String>{
        'CUST_ID' => 'Record ID',
        'CUST_NAME' => 'Name',
        'CUST_CURRENCY_ISO_CODE' => 'Currency', 
        'CUST_OWNER_NAME' => 'Owner Name', 
        'CUST_OWNER_ALIAS' => 'Owner Alias',
        'CUST_OWNER_ROLE' => 'Owner Role',     
        'CUST_CREATED_NAME' => 'Created By',
        'CUST_CREATED_ALIAS' => 'Created By Alias',
        'CUST_CREATED_DATE' => 'Created Date',     
        'CUST_LAST_UPDATE_NAME' => 'Last Modified By',
        'CUST_LAST_UPDATE_ALIAS' => 'Last Modified By Alias',
        'CUST_LAST_UPDATE' => 'Last Modified Date',
        'CUST_LAST_ACTIVITY' => 'Last Activity Date'
    };

    
    //Method that retrieves list of Account Payable records(converted to Payment Proposal Lines) from the Payment Proposal record
    public static Object search(Id paymentProposalId) {
        try {
            //Query payment Proposal
            Payment_Proposal__c paymentProposal= queryPaymentProposal(paymentProposalId);
            return PaymentProposalSearchService.search(paymentProposal);
        }
        catch(Exception e) {
            throw new PaymentProposalException(e.getMessage());
        }  
    }

    @AuraEnabled(cacheable=true)
    public static Object getResultsTableColumnDetails(){
        try {
            FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest('AcctSeed__Account_Payable__c',
            'AcctSeed__Payment_Proposal_Search','','');
            FieldSetHandler cols = new FieldSetHandler(fsRequest); 
            return cols.response.mainColumns;
        }
        catch(Exception e) {
            throw new PaymentProposalException(e.getMessage());
        }  
    }

    /**
     * This method is used to convert the payable to PPL and show it on result section on advance search component
     */
    @AuraEnabled
    public static Object createPPLinesForPayables(String payableIds, String ppId){
        try {
            List<Payment_Proposal_Line__c> ppLines = new  List<Payment_Proposal_Line__c>(); 
            List<Id> payables = ( List<Id>) JSON.deserialize(payableIds, List<Id>.class);
            List<Account_Payable__c> payablesData = queryPayables(payables);
            Payment_Proposal_Line__c ppLine;
            Payment_Proposal__c pp = queryPaymentProposal(ppId);
            Map<Id, Id> mapOfVendorIdWithParentId = new Map<Id, Id>();

            if(pp.Aggregate_by_Payee__c) {
                mapOfVendorIdWithParentId  = getParentPPL(payablesData,ppId);
            }

            for(Account_Payable__c payble : payablesData) {
                ppLine = new Payment_Proposal_Line__c();
                ppLine.Payable__c = payble.Id;
                ppLine.Vendor__c = payble.Vendor__c;
                ppLine.Payment_Proposal__c = ppId;
                ppLine.Parent__c = (pp.Aggregate_by_Payee__c == true) ? mapOfVendorIdWithParentId.get(payble.Vendor__c) : null;
                if(payble.On_Hold__c == false)
                {
                    ppLines.add(ppLine);
                }
            }

            SFDCSecurityUtils.insertCheckCRUDAndFLS(ppLines, new List<String>{'Payable__c', 'Payment_Proposal__c', 'Vendor__c'});

            return ppLines;

        } catch (DMLException e) {
            throw new PaymentProposalException(e.getDmlMessage(0)); 
        } catch (Exception e) {
            throw new PaymentProposalException(e.getMessage() + ' Line : ' + e.getLineNumber());
        }
    }

    @AuraEnabled
    public static Object basicSearch(String ppId, String ppJSON){
        try {
            Map<String, Object> ppObject = (Map<String, Object>)JSON.deserializeUntyped(ppJSON);
            Payment_Proposal__c pp = new Payment_Proposal__c();

            SObjectField fieldToken; 
            
            for(String fld : ppObject.keySet()) {
                fieldToken = SchemaDescribe.getDescribe(Payment_Proposal__c.SobjectType).getField(fld);
                Schema.DisplayType dfr = fieldToken.getDescribe().getType();
                if(dfr.Name() == 'DATE'){
                    pp.put(fld, ppObject.get(fld) == null ? null : Date.valueOf(String.valueOf(ppObject.get(fld))));
                }else if(dfr.Name() == 'DOUBLE'){
                    Object value = ppObject.get(fld);
                    if(value != '' && value !=NULL){
                        pp.put(fld,Double.valueOf(value));
                    }else{
                        Double doubleVar;
                        pp.put(fld,doubleVar);
                    }   
                }else{
                    pp.put(fld, ppObject.get(fld));
                }
            }
            pp.put('Id', ppId);
            
            SFDCSecurityUtils.updateCheckCRUDAndFLS(pp, new List<String>(ppObject.keySet()));

            return search(ppId);
        } catch (Exception e) {
            throw new PaymentProposalException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Object getAllReports() {
        try {
            //Query payment Proposal
           return queryReports('Payment Proposal Search Reports');
        }
        catch(Exception e) {
            throw new PaymentProposalException(e.getMessage());
        }  
    }

    @AuraEnabled
    public static Object getReportFilters(String reportName) {
        try {
            AcctSeedReportManager reportManager  = AcctSeedReportManager.getInstance()
                                                                        .setStandardCUSTFields(mapOfFieldNameWithAPIName)
                                                                        .getReportId(reportName)
                                                                        .runReportResultWithFactDetails()
                                                                        .getReportMetdata()
                                                                        .getReportFilters()
                                                                        .getReportFiltersDetails();
           return reportManager.filterDetails;  
        }
        catch(Exception e) {
            throw new PaymentProposalException(e.getMessage());
        }  
    }

    @AuraEnabled
    public static Object setReportFilters(String filters, String reptName, String ppId) {
        try {
            List<ReportFilters> reptFilters = (List<ReportFilters>) JSON.deserialize(filters, List<ReportFilters>.class);

            Payment_Proposal__c pp = queryPaymentProposal(ppId);
            String currencyISOCodeOnPaymentProposal ;
            if(MultiCurrencyHandler.isMultiCurrencyEnabled){
                currencyISOCodeOnPaymentProposal = (String)pp.get('CurrencyISOCode');
            }
            
            if(reptFilters.size() > 0) {
                saveFiltersToPPRecord(ppId, reptFilters);
            }

            AcctSeedReportManager reportManager  = AcctSeedReportManager.getInstance()
                                                                        .setStandardCUSTFields(mapOfFieldNameWithAPIName)
                                                                        .getReportId(reptName)
                                                                        .runReportResultWithFactDetails()
                                                                        .getReportMetdata()
                                                                        .setReportFilters(reptFilters,currencyISOCodeOnPaymentProposal)
                                                                        .getReportRowsFromFactDetails() //to get rows from above factmap
                                                                        .getReportDetailColumns() //to get report column api names and that can be extract after getting report metadata
                                                                        .getReportHeaderValue() //to get column datatypes corrsponding to column api name
                                                                        .setNeededColumnName(new List<String>{'CUST_NAME'}) //needed column used to tell that these two column we need from report
                                                                        .getDataFromReport();
            Map<String, List<AcctSeedReportData>> colApiNameToReportData = reportManager.colApiNameToReportData;
            Payment_Proposal__c paymentProposal = queryPaymentProposal(ppId);
            return PaymentProposalSearchService.searchPayables(paymentProposal, colApiNameToReportData.get('CUST_NAME')); 
        }
        catch(Exception e) {
            throw new PaymentProposalFilterException(e.getMessage());
        }  
    }
  
    public static void  saveFiltersToPPRecord(String ppId, List<ReportFilters> reptFilters) {
        Payment_Proposal__c pp = new Payment_Proposal__c();
        pp.Id = ppId;
        pp.AcctSeed__Report_Filters__c = '';
        for(ReportFilters filter : reptFilters) {
             filter.value = filter.value.replace('\n','');
             pp.AcctSeed__Report_Filters__c += filter.initialReportColumnName + ' ' + filter.operator + ' ' + filter.value +   '\n';
        }
        
        SFDCSecurityUtils.updateCheckCRUDAndFLS(pp, new List<String>{
            'Report_Filters__c'
        });
    }

    @AuraEnabled
    public static void  saveReportNameToPPRecord(String ppId, String reportName) {
        Payment_Proposal__c pp = new Payment_Proposal__c();
        pp.Id = ppId;
        pp.AcctSeed__Report_Name__c = reportName;
        pp.AcctSeed__Report_Filters__c = null;

        SFDCSecurityUtils.updateCheckCRUDAndFLS(pp, new List<String>{
             'Report_Name__c',
             'Report_Filters__c'
        });
    }

    //Call batch to process single Payment proposal record
    @AuraEnabled
    public static void publishSinglePaymentProposal(String ppJSON){
        Payment_Proposal__c paymentProposal = (Payment_Proposal__c) JSON.deserialize(ppJSON, Payment_Proposal__c.class);
        Database.executeBatch(new PaymentProposalBatch(paymentProposal));
    }
  
    //Call batch to process multiple Payment proposal record
    public static void publishMultiplePaymentProposals(){
        Database.executeBatch(new PaymentProposalBatch());
    }

    private static List<Account_Payable__c> queryPayables(List<Id> payableIds) {
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Vendor__c',
            'Balance__c',
            'On_Hold__c'
        };
         //Add query condition
         String queryCondition = 'Id IN: payableIds' ;
       
         //Final assembly of SOQL string
         SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
         theQuery
             .assertIsAccessible()
             .setEnforceFLS(false)
             .selectFields(fieldsToQuery)
             .setCondition(queryCondition);
 
        return Database.query(theQuery.toSOQL());
    }

    private static Payment_Proposal__c queryPaymentProposal(Id paymentProposalId) {

        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name',
            'Account__c',
            'Aggregate_by_Payee__c',
            'Alternate_Payee__c',
            'Conditions_Met__c',
            'Payable_Name__c',
            'Payee_Reference__c',
            'Relative_Due_Date_Number_n__c',
            'Payment_Proposal_Date__c',
            'Proprietary_Payable_Number__c',
            'Relative_Due_Date__c',
            'Relative_Early_Pay_Date_Number_n__c',
            'Relative_Early_Pay_Date__c',
            'Relative_Issue_Date_Number_n__c',
            'Relative_Issue_Date__c',
            'Payable_Name_Operator__c',
            'Payee_Reference_Operator__c',
            'Alternate_Payee_Operator__c',
            'Proprietary_Payable_Number_Operator__c',
            'Conditions_Met__c',
            'Posting_Status__c',
            'On_Hold__c'
        };

        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            fieldsToQuery.add('CurrencyISOCode');
        }

     
        //Add query condition
        String queryCondition = 'Id = :paymentProposalId';
       
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Payment_Proposal__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        //Call DML operation
        return Database.query(theQuery.toSOQL());

    }

    private static List<Report> queryReports(String folderName) {

        String format  = 'Tabular';
        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Name'
        };

     
        //Add query condition
        String queryCondition = 'FolderName = :folderName AND Format=:format';
       
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Report.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        //Call DML operation
        return Database.query(theQuery.toSOQL());

    }
    
    //Method to update Payment Proposal Record
    @AuraEnabled
    public static Object updatePaymentProposalRecord(String ppId, String mapOfFieldApiNameAndVal){
        try{
            Map<String, Object> fieldApiNameAndValMap = (Map<String, Object>) JSON.deserializeUntyped(mapOfFieldApiNameAndVal);
            Payment_Proposal__c pp = new Payment_Proposal__c();
            if (fieldApiNameAndValMap.keySet().size() > 0) {
                for(String fld : fieldApiNameAndValMap.keySet()) {
                    pp.put(fld, fieldApiNameAndValMap.get(fld));
                }
                pp.put('Id', ppId);
                
                SFDCSecurityUtils.updateCheckCRUDAndFLS(pp, new List<String>(fieldApiNameAndValMap.keySet()));
            }
            return pp;
        }catch(Exception e) {
            throw new PaymentProposalException(e.getMessage());
        }  
    }

    //Get or Insert the Parent PPL
    private static Map<Id, Id> getParentPPL(List<Account_Payable__c> payablesData, Id ppId) {
        
        Set<Id> vendorIds = new Set<Id>();
        Map<Id, Id> mapOfVendorIdWithParentId = new Map<Id, Id>();
        Map<Id,Payment_Proposal_Line__c> pplToInsert = new  Map<Id,Payment_Proposal_Line__c>();
        
        //Get all the vendor Ids from Payables
        for(Account_Payable__c payable : payablesData) {
            vendorIds.add(payable.Vendor__c);
        }

        if(vendorIds != null) {
             //Get all the existing PPL with parent
            for(Payment_Proposal_Line__c ppl : queryPaymentProposalLines(vendorIds,ppId)) {
                if(!mapOfVendorIdWithParentId.containsKey(ppl.Vendor__c)) {
                    mapOfVendorIdWithParentId.put(ppl.Vendor__c, ppl.Parent__c);
                }
            }

            //Insert new parent PPL if not present corresponding to vendor
            for(Id vId : vendorIds) {
                if(!mapOfVendorIdWithParentId.containsKey(vId)) {
                    pplToInsert.put(vId,new Payment_Proposal_Line__c(
                        Vendor__c = vId,
                        Payment_Proposal__c = ppId
                    ));
                }
            }

            if(!pplToInsert.isEmpty()) {
                SFDCSecurityUtils.insertCheckCRUDAndFLS(pplToInsert.values(), new List<String>{'Vendor__c', 'Payment_Proposal__c'});
            }

            //Assign map of vendor Id with Parent PPL Id
            for(Id vId : pplToInsert.keySet()) {
                mapOfVendorIdWithParentId.put(vId,pplToInsert.get(vId).Id);
            }
        }

       return mapOfVendorIdWithParentId;
    }

    private static List<Payment_Proposal_Line__c> queryPaymentProposalLines(Set<Id> vendorIds, Id ppId) {

        //=================================================
        //build dynamic SOQL query using SOQLBuilder class
        //=================================================
        //Select fields
        List<String> fieldsToQuery = new List<String> {
            'Id',
            'Parent__c',
            'Vendor__c'
        };

     
        //Add query condition
        String queryCondition = 'Vendor__c = :vendorIds AND Parent__c != null AND Payment_Proposal__c = :ppId';
       
        //Final assembly of SOQL string
        SOQLBuilder theQuery = new SOQLBuilder(Payment_Proposal_Line__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(false)
            .selectFields(fieldsToQuery)
            .setCondition(queryCondition);

        //Call DML operation
        return Database.query(theQuery.toSOQL());
    }

    @AuraEnabled
    public static String getCurrencyISOCode(String recordId){
        String currencyisoCode = '';
        try{
            Payment_Proposal__c paymentProposal = queryPaymentProposal(recordId);
            if (MultiCurrencyHandler.isMultiCurrencyEnabled){
                currencyisoCode = (string) paymentProposal.get('currencyisocode');
            }
        } catch (Exception e){
            throw new PaymentProposalException(e.getMessage());
        }
        return currencyisoCode;
    }

}