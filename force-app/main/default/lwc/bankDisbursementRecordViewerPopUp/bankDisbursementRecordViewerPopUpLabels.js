import BANK_DISBURSEMENT_SEARCH_FIELDSET from '@salesforce/label/c.BANK_DISBURSEMENT_SEARCH_FIELDSET';
import commonLoading from '@salesforce/label/c.COMMON_LOADING';
import COMMON_CLOSE from '@salesforce/label/c.COMMON_CLOSE';
import COMMON_CASH_DISBURSEMENT from '@salesforce/label/c.COMMON_CASH_DISBURSEMENT';
import COMMON_JOURNAL_ENTRY_LINE from '@salesforce/label/c.COMMON_JOURNAL_ENTRY_LINE';
import ERR_IN_OBJ_DETAILS from '@salesforce/label/c.ERR_IN_OBJ_DETAILS';

export const bankDisbursementPopUpLabels = () => {
    return {
        BANK_DISBURSEMENT_SEARCH_FIELDSET,
        commonLoading,
        COMMON_CASH_DISBURSEMENT,
        COMMON_JOURNAL_ENTRY_LINE,
        COMMON_CLOSE,
        ERR_IN_OBJ_DETAILS
    }
}