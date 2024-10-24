import {api, LightningElement, track, wire} from 'lwc';
import {TaxSettings, Address} from 'c/sobject';
import {getFieldValue, getRecord} from "lightning/uiRecordApi";
import {CloseActionScreenEvent} from "lightning/actions";
import { LabelService } from "c/utils"; 

export default class AddressValidatorTaxSettings extends LightningElement {
    @api recordId;
    @api sObjectName;

    @track addressId;

    showSpinner = true;
    fields;
    labels = LabelService;
    addressObjectApiName = Address.objectApiName;

    connectedCallback() {
        this.fields = [TaxSettings.originAddress];
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: '$fields'
    })
    fetchCommonRecord({data, error}) {
        if (data) {
            this.addressId = getFieldValue(data, TaxSettings.originAddress);
            this.showSpinner = false;
        }
    }

    closeQuickAction(detail) {
        let aCustomCloseEvent = new CustomEvent('closequickaction', {detail});
        this.dispatchEvent(aCustomCloseEvent);
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}