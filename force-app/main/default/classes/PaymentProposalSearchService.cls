public with sharing class PaymentProposalSearchService {

    public class PaymentProposalSearchServiceException extends Exception {}

    //Map containing all operators
    private static FINAL Map<String, String> mapOfOperators = new Map<String, String>{
            'equals' => '=',
            'not equal to' => '!=',
            'starts with' => 'Like',
            'contains' => 'Like',
            'does not contain' => 'Like'};

    //Method To retrieve list of Account Payable records(converted to Payment Proposal Lines) from the Payment Proposal record
    public static Object search(Payment_Proposal__c paymentProposal) {
        List<String> existedPayableIds = new List<String>();
        List<Account_Payable__c> accountPayables = new List<Account_Payable__c>();
        
        try {
            FieldSetHandler.FieldSetRequest fsRequest = new FieldSetHandler.FieldSetRequest('AcctSeed__Account_Payable__c',
                            'AcctSeed__Payment_Proposal_Search','','');
            
            FieldSetHandler cols = new FieldSetHandler(fsRequest);

            for(Payment_Proposal_Line__c ppl : getPPLines(paymentProposal.Id)){
                if(ppl.Payable__c != null){
                    existedPayableIds.add(ppl.Payable__c);
                }
            }
            
            String conditionOperator = (paymentProposal.AcctSeed__Conditions_Met__c == '--None--' || String.isBlank(paymentProposal.AcctSeed__Conditions_Met__c))?'AND':((paymentProposal.AcctSeed__Conditions_Met__c == 'All')?'AND':'OR');
            
            //Get all fields from Account Payable
            List<String> fieldnames = new List<String>(cols.response.fieldNames);

            //Creation of WHERE Clause for String Type Field
            String queryCondition = '';
            queryCondition = getWhereConditionForStringFields(conditionOperator,paymentProposal.Payable_Name__c,paymentProposal.Payable_Name_Operator__c,'Name ',queryCondition);

            queryCondition += getWhereConditionForStringFields(conditionOperator,paymentProposal.Proprietary_Payable_Number__c,paymentProposal.Proprietary_Payable_Number_Operator__c,'  Proprietary_Payable_Number__c ',queryCondition);

            queryCondition += getWhereConditionForStringFields(conditionOperator,paymentProposal.Payee_Reference__c,paymentProposal.Payee_Reference_Operator__c,' Payee_Reference__c ',queryCondition);

            queryCondition += getWhereConditionForStringFields(conditionOperator,paymentProposal.Alternate_Payee__c,paymentProposal.Alternate_Payee_Operator__c,' Payee__c ',queryCondition);

            //Creation of WHERE Clause for Date Type Field
            queryCondition += (paymentProposal.Relative_Due_Date__c != null && paymentProposal.Payment_Proposal_Date__c != NULL)? generateSOQLWhereClauseForDateField(conditionOperator,paymentProposal.Payment_Proposal_Date__c,'Due_Date__c',paymentProposal.Relative_Due_Date__c,Integer.ValueOf(paymentProposal.Relative_Due_Date_Number_n__c)):'';

            queryCondition += (paymentProposal.Relative_Issue_Date__c != null && paymentProposal.Payment_Proposal_Date__c != NULL)?generateSOQLWhereClauseForDateField(conditionOperator,paymentProposal.Payment_Proposal_Date__c,'Date__c',paymentProposal.Relative_Issue_Date__c,Integer.ValueOf(paymentProposal.Relative_Issue_Date_Number_n__c)):'';

            queryCondition += (paymentProposal.Relative_Early_Pay_Date__c != null && paymentProposal.Payment_Proposal_Date__c != NULL)? generateSOQLWhereClauseForDateField(conditionOperator,paymentProposal.Payment_Proposal_Date__c,'EarlyPayDate__c',paymentProposal.Relative_Early_Pay_Date__c,Integer.ValueOf(paymentProposal.Relative_Early_Pay_Date_Number_n__c)):'';            

            //Add Conditions for Some more fields
            queryCondition +=(paymentProposal.On_Hold__c)?' '+ conditionOperator +' On_Hold__c = '+paymentProposal.On_Hold__c:'';
            queryCondition +=(paymentProposal.Posting_Status__c != NULL)?' '+ conditionOperator +' Status__c = '+' \'' + paymentProposal.Posting_Status__c+ '\'' : '';
            queryCondition +=(paymentProposal.Account__c!= NULL)?' '+ conditionOperator +' Vendor__c = '+' \'' +paymentProposal.Account__c+ '\'' : '';

            //Remove OR condition if it comes at first go and adjust null
            queryCondition = (queryCondition.trim()).removeStartIgnoreCase(conditionOperator);
            queryCondition = String.isBlank(queryCondition) ? '' : ' (' + queryCondition + ') '+ 'AND ';
            queryCondition += ' Balance__c != 0 AND Id NOT IN: existedPayableIds';

            if(MultiCurrencyHandler.isMultiCurrencyEnabled){
                String ppCurrencyISOCode = (String) paymentProposal.get('CurrencyIsoCode');
                fieldnames.add('CurrencyISOCode');
                queryCondition += ' AND CurrencyISOCode = :ppCurrencyISOCode';
            }

            //Building the SOQL
            SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
            theQuery
            .setEnforceFLS(true)
            .selectFields(fieldnames)
            .setCondition(queryCondition);

            //Executing query
            accountPayables = Database.query(theQuery.toSOQL());
            return new AdvanceSearchWrapper(cols.response.mainColumns, accountPayables);
        }  
        catch(Exception e) {
            throw new PaymentProposalSearchServiceException(e.getMessage());
        }
    }

    public static String getWhereClauseForNextorLastOperator(Date paymentProposalDate, String dateFieldName,String dateFieldOperator, Integer valueOfN){
        String whereCondition = '';
        String startDate = getValidDateFormat(paymentProposalDate);
        String endDate = getValidDateFormat(paymentProposalDate);

        List<String> listOfOperator = new List<String>{'>=', '<='};
        if (valueOfN < 0) {
            listOfOperator = new List<String>{'<=', '>='};
        }
        
        if (dateFieldOperator.contains('DAYS')) {
            startDate = (valueOfN > 0)?getValidDateFormat(paymentProposalDate.addDays(1)):getValidDateFormat(paymentProposalDate);
            endDate = getValidDateFormat(paymentProposalDate.addDays(valueOfN));
        } else if (dateFieldOperator.contains('WEEKS')) {
            startDate = (valueOfN > 0)?getValidDateFormat(paymentProposalDate.toStartofWeek().addDays(7)):getValidDateFormat(paymentProposalDate.toStartofWeek().addDays(-1));
            endDate = (valueOfN > 0)?getValidDateFormat(paymentProposalDate.toStartofWeek().addDays((7 * valueOfN)+6)):getValidDateFormat(paymentProposalDate.toStartofWeek().addDays((7 * valueOfN)));
        } else if (dateFieldOperator.contains('MONTHS')) {
            startDate = (valueOfN > 0)?getValidDateFormat(paymentProposalDate.toStartOfMonth().addMonths(1)):(getValidDateFormat(paymentProposalDate.toStartOfMonth().addDays(-1)));
            endDate = (valueOfN > 0)?getValidDateFormat(paymentProposalDate.toStartOfMonth().addMonths(valueOfN + 1).addDays(-1)):(getValidDateFormat(paymentProposalDate.toStartOfMonth().addMonths(valueOfN)));
        } else if (dateFieldOperator.contains('QUARTERS')) {
            startDate = (valueOfN > 0)?getValidDateFormat(getFirstDateOfQuarter(paymentProposalDate).addMonths(3)):getValidDateFormat(getFirstDateOfQuarter(paymentProposalDate).addDays(-1));
            endDate = (valueOfN > 0)?getValidDateFormat(getFirstDateOfQuarter(paymentProposalDate).addMonths(3 + (3 * valueOfN)).addDays(-1)):getValidDateFormat(getFirstDateOfQuarter(paymentProposalDate).addMonths(3 * valueOfN));
        }

        whereCondition += dateFieldName + listOfOperator[0] +startDate +' AND '+ dateFieldName + listOfOperator[1] +endDate;
        
        return whereCondition;
    }

    public static Date getFirstDateOfQuarter(Date inputDate) {
        Integer quarter = (inputDate.month() - 1) / 3 + 1; 
        Integer year = inputDate.year();

        // Calculate the first date of the quarter
        Integer month = (quarter - 1) * 3 + 1;
        Date firstDateOfQuarter = Date.newInstance(year, month, 1);
        
        return firstDateOfQuarter;
    }
    
    private static String calculateDueDate(String conditionOperator,Date paymentProposalDate, String dateFieldName, String dateFieldOperator, Integer valueOfN) {
        String whereCondition ='';
        if(dateFieldOperator.contains('NEXT') && (valueOfN > 0 || valueOfN < 0)) {
            whereCondition += ' '+conditionOperator +' ('+getWhereClauseForNextorLastOperator(paymentProposalDate,dateFieldName,dateFieldOperator,valueOfN) + ') ';
        } else if (dateFieldOperator.contains('LAST') && dateFieldOperator.contains(' n ') && (valueOfN > 0 || valueOfN < 0)) {
            whereCondition += ' '+conditionOperator +' ('+getWhereClauseForNextorLastOperator(paymentProposalDate,dateFieldName,dateFieldOperator,-valueOfN) + ') ';
        }else if (dateFieldOperator.contains('THIS')){
            whereCondition = ' '+conditionOperator +' (';
            if (dateFieldOperator.contains('THIS WEEK')) {
                Integer daysUntilMonday = paymentProposalDate.toStartOfWeek().daysBetween(paymentProposalDate);
                Date weekStart = paymentProposalDate.addDays(-daysUntilMonday);
                Date weekEnd = weekStart.addDays(6);
                whereCondition += dateFieldName+' >= ' + getValidDateFormat(weekStart) +
                                ' AND '+ dateFieldName+' <= ' + getValidDateFormat(weekEnd);
            }else if(dateFieldOperator.contains('THIS MONTH')){
                Date monthStart = Date.newInstance(paymentProposalDate.year(), paymentProposalDate.month(), 1);
                Date monthEnd = monthStart.addMonths(1).addDays(-1);
                whereCondition += dateFieldName+' >= ' + getValidDateFormat(monthStart) +
                                ' AND '+dateFieldName+' <= ' + getValidDateFormat(monthEnd);
            }else if(dateFieldOperator.contains('THIS QUARTER')){
                Integer quarterMonth = ((paymentProposalDate.month() - 1) / 3) * 3 + 1;
                Date quarterStart = Date.newInstance(paymentProposalDate.year(), quarterMonth, 1);
                Date quarterEnd = quarterStart.addMonths(3).addDays(-1);
                whereCondition += dateFieldName+' >= ' + getValidDateFormat(quarterStart) +
                                ' AND '+dateFieldName+' <= ' + getValidDateFormat(quarterEnd);
            }
            whereCondition += ') ';
        }else if(dateFieldOperator.contains('LAST') && (!dateFieldOperator.contains(' n '))){   
            whereCondition = ' '+conditionOperator +' (';
            if (dateFieldOperator.contains('LAST WEEK')) {
                Integer daysUntilMonday = paymentProposalDate.toStartOfWeek().daysBetween(paymentProposalDate);
                Date weekStart = paymentProposalDate.addDays(-daysUntilMonday - 7); // Go back 7 days from the start of the current week
                Date weekEnd = weekStart.addDays(6);
                whereCondition += dateFieldName + ' >= ' + getValidDateFormat(weekStart) + ' AND ' + dateFieldName + ' <= ' + getValidDateFormat(weekEnd);
            }else if(dateFieldOperator.contains('LAST MONTH')){
                Date monthStart = Date.newInstance(paymentProposalDate.year(), paymentProposalDate.month() - 1, 1);
                Date monthEnd = monthStart.addMonths(1).addDays(-1);
                whereCondition += dateFieldName + ' >= ' + getValidDateFormat(monthStart) + ' AND ' + dateFieldName + ' <= ' + getValidDateFormat(monthEnd);
            }else if(dateFieldOperator.contains('LAST QUARTER')){
                Integer quarterMonth = ((paymentProposalDate.month() - 1) / 3) * 3 - 2; // Go back 3 months from the current quarter
                Date quarterStart = Date.newInstance(paymentProposalDate.year(), quarterMonth, 1);
                Date quarterEnd = quarterStart.addMonths(3).addDays(-1);
                whereCondition += dateFieldName + ' >= ' + getValidDateFormat(quarterStart) + ' AND ' + dateFieldName + ' <= ' + getValidDateFormat(quarterEnd);
            }
            whereCondition += ') ';
        }
        return whereCondition;
    }

    private static String generateSOQLWhereClauseForDateField(String conditionOperator,Date paymentProposalDate,String dateFieldName, String dateFieldOperator, Integer valueOfN) {
        String whereClause ='';

        if (dateFieldOperator.contains('TODAY')) {
            whereClause += ' '+conditionOperator +' '+dateFieldName +' = '+getValidDateFormat(paymentProposalDate)+' ';
        }else if (dateFieldOperator.contains('TOMORROW')) {
            whereClause += ' '+conditionOperator +' '+dateFieldName +' = '+getValidDateFormat(paymentProposalDate.addDays(1))+' ';
        }else if (dateFieldOperator.contains('YESTERDAY')) {
            whereClause += ' '+conditionOperator +' '+dateFieldName +' = '+getValidDateFormat(paymentProposalDate.addDays(-1))+' ';
        }else if (dateFieldOperator.contains('NEXT') || dateFieldOperator.contains('LAST') || dateFieldOperator.contains('THIS')) {
            whereClause += calculateDueDate(conditionOperator,paymentProposalDate, dateFieldName, dateFieldOperator, valueOfN);
        }
        return whereClause;
    }

    private static String getValidDateFormat(Date paymentProposalDate){
        return DateTime.newInstance(paymentProposalDate, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
    }

    //Create WHERE Clause for String type Fields for Basic Search
    private static String getWhereConditionForStringFields(String conditionOperator,String ppFieldName, String ppFieldOperator, String payableFieldName,String currentQueryCondition){
        String queryCondition = '';
        if(ppFieldName != null){
            if(ppFieldOperator == 'contains'){
                queryCondition += (' '+conditionOperator+' '+payableFieldName+' '+ mapOfOperators.get(ppFieldOperator) + '  \'' +'%'+ ppFieldName +'%'+ '\'');
            }else if(ppFieldOperator == 'does not contain'){
                queryCondition += (String.IsBlank(currentQueryCondition))?(' ('+' NOT '+payableFieldName+' '+ mapOfOperators.get(ppFieldOperator) + '  \'' +'%'+ ppFieldName +'%'+ '\''+')'):' '+conditionOperator+(' ('+' NOT '+payableFieldName+' '+ mapOfOperators.get(ppFieldOperator) + '  \'' +'%'+ ppFieldName +'%'+ '\''+')');
            }else if(ppFieldOperator == 'starts with'){
                queryCondition += (' '+conditionOperator+' '+payableFieldName+' '+ mapOfOperators.get(ppFieldOperator) + '  \'' + ppFieldName +'%'+ '\'');
            }else if(ppFieldOperator == null){
                queryCondition += (' '+conditionOperator+' '+payableFieldName+' '+ mapOfOperators.get('equals') + '  \'' + ppFieldName + '\'');
            }else{
                queryCondition += (' '+conditionOperator+' '+payableFieldName+' '+ mapOfOperators.get(ppFieldOperator) + '  \'' + ppFieldName + '\'');
            }
       }
        
        return queryCondition;
    }

    public static Object searchPayables(Payment_Proposal__c paymentProposal, List<AcctSeedReportData> reportAllData) {
        List<String> existedPayableIds = new List<String>();
        List<String> payableIds = new List<String>();
        List<Account_Payable__c> payables = new List<Account_Payable__c>();

        //Executing query
       for(Payment_Proposal_Line__c ppl : getPPLines(paymentProposal.Id)){
            if(ppl.Payable__c != null){
               existedPayableIds.add(ppl.Payable__c);
           }
        }
         
        for(AcctSeedReportData reportData : reportAllData) {
            String payableId = (String) JSON.deserialize(reportData.value, String.class);
            
            if(existedPayableIds.contains(payableId)){
                continue;
            }   
            payableIds.add(payableId);
        }

        FieldSetHandler cols = new FieldSetHandler(new FieldSetHandler.FieldSetRequest('AcctSeed__Account_Payable__c', 'AcctSeed__Payment_Proposal_Search', '' , ''));
        List<String> fieldnames = new List<String>(cols.response.fieldNames);
        String queryCondition = 'ID IN :payableIds';
        //if multi currency add where clause to filter out payables that don't match currency on PP
        if(MultiCurrencyHandler.isMultiCurrencyEnabled){
            String ppCurrencyISOCode = (String) paymentProposal.get('CurrencyIsoCode');
            queryCondition += ' AND CurrencyISOCode = :ppCurrencyISOCode';
        }
        SOQLBuilder theQuery = new SOQLBuilder(Account_Payable__c.SObjectType);
        theQuery
            .assertIsAccessible()
            .setEnforceFLS(true)
            .selectFields(fieldnames)
            .setCondition(queryCondition);
        return new AdvanceSearchWrapper(cols.response.mainColumns, Database.query(theQuery.toSOQL()));

    }

    /**
     * Method used to return existed PPlines to prevent duplicacy in creating same PPLines in both
     * advance and basic search
     */
    public static List<Payment_Proposal_Line__c> getPPLines(Id paymentProposalId) {
        List<String> fieldnames = new List<String>{'Payable__c', 'Payment_Proposal__c'};
        String queryCondition = 'Payment_Proposal__c=: paymentProposalId';

        SOQLBuilder theQuery = new SOQLBuilder(Payment_Proposal_Line__c.SObjectType);
        theQuery
        .setEnforceFLS(true)
        .selectFields(fieldnames)
        .setCondition(queryCondition);
        
        return (List<Payment_Proposal_Line__c>) Database.query(theQuery.toSOQL());
    }

    public class AdvanceSearchWrapper {
        @AuraEnabled
        public Object columns;
        @AuraEnabled
        public Object data;
        
        public AdvanceSearchWrapper(Object columns, Object data) {
            this.columns = columns;
            this.data = data;
        }
    }
 }