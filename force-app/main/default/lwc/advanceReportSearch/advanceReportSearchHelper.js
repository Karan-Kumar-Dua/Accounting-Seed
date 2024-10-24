import REPORT_NAME_FIELD from "@salesforce/schema/Payment_Proposal__c.Report_Name__c";
import ADVANCE_SEARCH_FIELD from "@salesforce/schema/Payment_Proposal__c.Advanced_Search__c";
import REPORT_FILTERS from "@salesforce/schema/Payment_Proposal__c.Report_Filters__c";
import ACCOUNT_FIELD from "@salesforce/schema/Payment_Proposal__c.Account__c";
import POSTING_STATUS_FIELD from "@salesforce/schema/Payment_Proposal__c.Posting_Status__c";
import ON_HOLD_FIELD from "@salesforce/schema/Payment_Proposal__c.On_Hold__c";
import PAYABLE_NAME_FIELD from "@salesforce/schema/Payment_Proposal__c.Payable_Name__c";
import PAYABLE_NAME_OPERATOR_FIELD from "@salesforce/schema/Payment_Proposal__c.Payable_Name_Operator__c";
import PAYEE_REF_FIELD from "@salesforce/schema/Payment_Proposal__c.Payee_Reference__c";
import PAYEE_REF_OPERATOR_FIELD from "@salesforce/schema/Payment_Proposal__c.Payee_Reference_Operator__c";
import ALTERNATE_PAYEE_FIELD from "@salesforce/schema/Payment_Proposal__c.Alternate_Payee__c";
import ALTERNATE_PAYEE_OPERATOR_FIELD from "@salesforce/schema/Payment_Proposal__c.Alternate_Payee_Operator__c";
import PROP_PAYABLE_NUMBER_FIELD from "@salesforce/schema/Payment_Proposal__c.Proprietary_Payable_Number__c";
import PROP_PAYABLE_NUMBER_OPERATOR_FIELD from "@salesforce/schema/Payment_Proposal__c.Proprietary_Payable_Number_Operator__c";
import PAYMENT_PROPOSAL_DATE_FIELD from "@salesforce/schema/Payment_Proposal__c.Payment_Proposal_Date__c";
import REILATIVE_ISSUE_DATE_NUM_FIELD from "@salesforce/schema/Payment_Proposal__c.Relative_Issue_Date_Number_n__c";
import RELATIVE_DUE_DATE_FIELD from "@salesforce/schema/Payment_Proposal__c.Relative_Due_Date__c";
import RELATIVE_ISSUE_DATE_FIELD from "@salesforce/schema/Payment_Proposal__c.Relative_Issue_Date__c";
import RELATIVE_DUE_DATE_NUM_FIELD from "@salesforce/schema/Payment_Proposal__c.Relative_Due_Date_Number_n__c";
import RELATIVE_EARLY_DATE_FIELD from "@salesforce/schema/Payment_Proposal__c.Relative_Early_Pay_Date__c";
import RELATIVE_EARLY_DATE_NUM_FIELD from "@salesforce/schema/Payment_Proposal__c.Relative_Early_Pay_Date_Number_n__c";
import CONDITIONS_MET_FIELD from "@salesforce/schema/Payment_Proposal__c.Conditions_Met__c";

export default class AdvanceReportSearchHelper {

    fetchBasicSearchFields() {
        return [CONDITIONS_MET_FIELD,ACCOUNT_FIELD, POSTING_STATUS_FIELD,ON_HOLD_FIELD,
            PAYABLE_NAME_OPERATOR_FIELD, PAYABLE_NAME_FIELD,PAYEE_REF_OPERATOR_FIELD, PAYEE_REF_FIELD,
            ALTERNATE_PAYEE_OPERATOR_FIELD, ALTERNATE_PAYEE_FIELD, PROP_PAYABLE_NUMBER_OPERATOR_FIELD, PROP_PAYABLE_NUMBER_FIELD,
            RELATIVE_DUE_DATE_FIELD, RELATIVE_DUE_DATE_NUM_FIELD, RELATIVE_ISSUE_DATE_FIELD,
            REILATIVE_ISSUE_DATE_NUM_FIELD, RELATIVE_EARLY_DATE_FIELD, RELATIVE_EARLY_DATE_NUM_FIELD, PAYMENT_PROPOSAL_DATE_FIELD
        ];
    }

    fetchOperatorSearchFields() {
        return [CONDITIONS_MET_FIELD,ACCOUNT_FIELD, POSTING_STATUS_FIELD,ON_HOLD_FIELD,
            PAYABLE_NAME_OPERATOR_FIELD, PAYABLE_NAME_FIELD,PAYEE_REF_OPERATOR_FIELD, PAYEE_REF_FIELD,
            ALTERNATE_PAYEE_OPERATOR_FIELD, ALTERNATE_PAYEE_FIELD, PROP_PAYABLE_NUMBER_OPERATOR_FIELD, PROP_PAYABLE_NUMBER_FIELD];
    }

    fetchDateRelatedSearchFields() {
        return [RELATIVE_DUE_DATE_FIELD, RELATIVE_DUE_DATE_NUM_FIELD, RELATIVE_ISSUE_DATE_FIELD,
            REILATIVE_ISSUE_DATE_NUM_FIELD, RELATIVE_EARLY_DATE_FIELD, RELATIVE_EARLY_DATE_NUM_FIELD];
    }

    fetchPaymentProposalDateField() {
        return PAYMENT_PROPOSAL_DATE_FIELD;
    }

    fetchReportFields() {
        return [REPORT_NAME_FIELD, ADVANCE_SEARCH_FIELD, REPORT_FILTERS];
    }
}