import { LightningElement } from 'lwc';
import runBatchJob from '@salesforce/apex/RerunPaymentProcessingJEHelper.runBatchJob';
import { NotificationService, LabelService } from "c/utils";
import { labels } from "./labelService";
export default class rerunPaymentProcessingJournalEntryService extends LightningElement {
    async runPaymentProcessingBatchJob() {
        try {
            await runBatchJob()
        } catch (err) {
            this.fireBackEvent();
            NotificationService.displayToastMessage(
                this,
                labels.reRunBatchInProgress,
                `${LabelService.commonToastErrorTitle}:`,
                'error'
            );
            return;
        }
        this.fireBackEvent();
        NotificationService.displayToastMessage(
            this,
            labels.reRunBatchInProgress,
            `${LabelService.commonToastSuccessTitle}:`,
            'success'
        );
    }
    fireBackEvent() {
        this.dispatchEvent(
            new CustomEvent('redirectback')
        );  
    }
}