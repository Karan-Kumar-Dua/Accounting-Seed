import {LightningElement} from "lwc";
import {NotificationService, StreamingApi, LabelService} from "c/utils";
import runDownloadTransactionJob from '@salesforce/apex/BankDirectConnectHelper.runDownloadTransactionJob';
import isAllowBDCAccess from '@salesforce/apex/BankDirectConnectHelper.isAllowBDCAccess';
import { ASImmediateEvent } from "c/sobject";
import BDCModal from 'c/bdcModal';
import Labels from './labels';


const CHANNEL_NAME = '/event/' + ASImmediateEvent.packageQualifier + 'AS_Immediate_Event__e';

export default class BankDirectConnect extends LightningElement {

    labels = {...Labels, ...LabelService};
    objEvent = new ASImmediateEvent();
    sa = new StreamingApi();
    showBankTransactionBtn = false;
    isUpdateButtonDisabled = false;
    isImportFileWizardOpen = false;
    allowBDCAccess = false;
    isUpdated = false;

    connectedCallback() {
        this.sa.channelName = CHANNEL_NAME;
        this.sa.customErrorCallback = this.errorCallback;
        this.sa.handleSubscribe(this.updateCallback);
        isAllowBDCAccess()
          .then(result => this.allowBDCAccess = result);
    }

    disconnectedCallback() {
        this.sa.handleUnsubscribe();
    }

    updateCallback = response => {
        if (response) {
            if (response.data.payload[this.objEvent.type] === 'BANK_TRANSACTIONS_DOWNLOAD_END') {
                this.isUpdated = true;
                this.displayUpdateSuccess(response.data.payload['AcctSeed__Payload__c']);
            }
            else if (response.data.payload[this.objEvent.type] === 'BANK_TRANSACTIONS_ERROR') {
                this.isUpdated = true;
                this.displayUpdateFail(response.data.payload['AcctSeed__Payload__c']);
            }
        }
    };
    showBankTransaction() {
        this.showBankTransactionBtn = true;
    }

    showBankRules() {
        this.showBankTransactionBtn = false;
    }

    showBankSettings() {
        this.showBankTransactionBtn = false;
    }

    handleUpdateAll() {
        this.isUpdated = false;
        this.isUpdateButtonDisabled = true;
        runDownloadTransactionJob();
        this.displayRunSuccess();
    }

    displayRunSuccess() {
        NotificationService.displayToastMessage(
            this,
            Labels.INF_BANK_UPDATE_IN_PROGRESS_ASYNC,
            Labels.INF_BANK_UPDATE_RUNNING
        );
    }

    displayUpdateSuccess(message) {
        NotificationService.displayToastMessage(
            this,
            Labels.INF_PLEASE_REFRESH_PAGE,
            message.replaceAll('"', ''));
    }

    displayUpdateFail(message) {
        NotificationService.displayToastMessage(this, message.replaceAll('"',''), Labels.INF_BANK_UPDATE_FAILED, "error", "sticky")
    }

    openImportFileWizard() {
        const importFileWizardModal = this.template.querySelector(`c-modal-popup-base[data-id="importFileWizardModal"]`);
        importFileWizardModal.openModal();
    }

    closeImportFileWizard(evt) {
        evt.stopPropagation();
        const importFileWizardModal = this.template.querySelector(`c-modal-popup-base[data-id="importFileWizardModal"]`);
        importFileWizardModal.closeModal();
    }

    refrshView(){
        this.template.querySelector('c-bdc-bank-credit-card-transactions').refreshCreditCardPage();
    }

    async handleRefresh() {
        BDCModal.open({
            size: 'small',
            modalData: {
                header: this.labels.bdcModalHeader,
                body: this.labels.bdcModalBody,
                cancelLabel : this.labels.commonNo,
                actionLabel : this.labels.commonYes
            },
            onsuccess: (e) => {
                e.stopPropagation();
                this.refrshView();
                this.isUpdateButtonDisabled = this.isUpdated === true ? false : this.isUpdateButtonDisabled;
              }
        });
    }
}