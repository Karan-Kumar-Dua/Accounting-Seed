import { LightningElement,api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';


export default class CardknoxMerchantAccountInfo extends LightningElement {
    @api recordId;

    hideMerchantKeyForm() {
        let merchantComp = this.template.querySelector(`[data-id="merchant-keys"]`);
        merchantComp && merchantComp.hideComp();

        let boardingcomp = this.template.querySelector(`[data-id="boarding-form"]`);
        boardingcomp && boardingcomp.showComp();
    }
    handleCancelButton(evt) {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}