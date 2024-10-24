import { LightningElement,api } from 'lwc';

export default class BillingReceivePaymentAdditionalFields extends LightningElement {
    @api wrappedData;

    @api reportValidity() {
        let isValid = true;
        let element = this.template.querySelectorAll('c-x-data-table-cell');
        element && element.forEach(item => {
            if (!item.reportValidity()) {
                isValid = false;
            }
        })
        return isValid;
    }
}