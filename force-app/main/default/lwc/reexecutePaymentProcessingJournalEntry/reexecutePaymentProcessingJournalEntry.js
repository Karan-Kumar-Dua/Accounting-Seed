import RerunPaymentProcessingJournalEntryService from 'c/rerunPaymentProcessingJournalEntryService';
export default class ReexecutePaymentProcessingJournalEntry extends RerunPaymentProcessingJournalEntryService {

    connectedCallback() {
        this.runPaymentProcessingBatchJob();
    }
}