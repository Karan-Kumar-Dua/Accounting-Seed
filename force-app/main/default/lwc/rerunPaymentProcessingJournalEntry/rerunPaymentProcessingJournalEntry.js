import { api } from 'lwc';
import RerunPaymentProcessingJournalEntryService from 'c/rerunPaymentProcessingJournalEntryService';
export default class RerunPaymentProcessingJournalEntry extends RerunPaymentProcessingJournalEntryService {

    isExecuting = false;

    @api async invoke() {
        if (this.isExecuting) {
            return;
        }
        this.isExecuting = true;
        await this.runPaymentProcessingBatchJob()
        this.isExecuting = false;
    }
}