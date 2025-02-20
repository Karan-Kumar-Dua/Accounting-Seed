import ERR_PAYMENT_SERVICES from '@salesforce/label/c.ERR_PAYMENT_SERVICES';
import PAYMENT_APPLICATION_PROCESS_DESCRIPTION from '@salesforce/label/c.PAYMENT_APPLICATION_PROCESS_DESCRIPTION';
import APPLY_PAYMENT_SERVICE from '@salesforce/label/c.APPLY_PAYMENT_SERVICE';
import APPLICATION_UNAVAILABLE from '@salesforce/label/c.APPLICATION_UNAVAILABLE';
import ERR_ON_PAYMENT_SERVICE_FOR_TRASACTIONAL_LEDGER from '@salesforce/label/c.ERR_ON_PAYMENT_SERVICE_FOR_TRASACTIONAL_LEDGER';

export const applyPaymentLabels = () => {

    return {
        ERR_PAYMENT_SERVICES,
        PAYMENT_APPLICATION_PROCESS_DESCRIPTION,
        APPLY_PAYMENT_SERVICE,
        APPLICATION_UNAVAILABLE,
        ERR_ON_PAYMENT_SERVICE_FOR_TRASACTIONAL_LEDGER
    }
}