import {api, LightningElement, wire} from 'lwc';
import {LabelService, NotificationService, ErrorUtils} from "c/utils";
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { CashDisbursement } from 'c/sobject';
import startDeleteAPDJob from "@salesforce/apex/DeleteAPDHelper.startDeleteAPDJob";
import validateAPDs from "@salesforce/apex/DeleteAPDHelper.validateAPDs";
import isDeleteAPDsAccess from '@salesforce/customPermission/Delete_APDs';

export default class DeleteCDAndAPDs extends LightningElement {
    @api recordId;
    @api ltngOut = false;
    @api callBacks;

    showSpinner = true;
    label = LabelService;
    recordName;
    error;
    noAPD = false;

    get isNoAPD() {
        return !this.error && this.noAPD;
    }

    get showModal() {
        return !this.error && !this.noAPD;
    }

    get isManual() {
        return this.source === CashDisbursement.SOURCE_VALUES.MANUAL;
    }

    get isPayable() {
        return this.source === CashDisbursement.SOURCE_VALUES.PAYABLE;
    }

    connectedCallback() {
        !isDeleteAPDsAccess && (
            this.showSpinner = false,
            this.error = LabelService.DELAPDsErrorNoAccess
        );
    }

    @wire(getRecord, {recordId: '$recordId', fields: [CashDisbursement.source]})
    fetchRecord({data, error}) {
        if (data) {
            this.source = getFieldValue(data, CashDisbursement.source);
            this.validateCD(data.id);
        }
    }

    validateCD(recordId) {
        isDeleteAPDsAccess && validateAPDs({cdId: recordId})
            .then((result) => {
                this.noAPD = result.includes(this.label.DELAPDsInfoNoAPD);
            })
            .catch((err) => {
                this.showSpinner = false;
                let {error} = ErrorUtils.processError(err);
                this.error = error;
            })
            .finally(() => {this.showSpinner = false});
    }

    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.callBacks && this.callBacks.backToRecord && this.callBacks.backToRecord();
    }

    deleteAPD() {
        isDeleteAPDsAccess && (
            this.showSpinner = true,
            startDeleteAPDJob({cdId: this.recordId})
                .then((result) => {
                    NotificationService.displayToastMessage(
                        this,
                        result,
                        LabelService.commonToastSuccessTitle,
                        'success'
                    );
                    this.closeQuickAction();
                }).catch((err) => {
                    this.showSpinner = false;
                    let {error} = ErrorUtils.processError(err);
                    this.error = error;
                })
        );
    }
}