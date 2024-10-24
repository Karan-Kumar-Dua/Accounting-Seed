import { LightningElement, api, track } from 'lwc';
import {NotificationService, LabelService} from "c/utils";

const SEVERITY = {
    success: 'success',
    error: 'error'
};

export default class LtngOutToastMessage extends LightningElement {

    labels = LabelService;
    timeoutRef;

    @api
    notifyError(opts) {
        this.notify(SEVERITY.error, opts);
    }

    @api
    notifySuccess(opts) {
        this.notify(SEVERITY.success, opts);
    }
    
    @api dismissable = false;
    @api ltngOut = false;

    @track severity = null;
    @track title = '';
    @track messages = [];

    get isSuccess() {
        return this.severity === SEVERITY.success && this.ltngOut;
    }

    get isError() {
        return this.severity === SEVERITY.error && this.ltngOut;
    }

    resetAutoClear = () => {
        if (this.timeoutRef) {
            clearTimeout(this.timeoutRef);
        }
        this.timeoutRef = setTimeout(() => {
            this.clear();
        }, 5000);
    }

    clear = () => {
        this.severity = null;
        this.title = '';
        this.messages = [];
    };

    notify(severity = SEVERITY.error, opts) {
        const cleanOpts = { title: '', messages: [], ...opts };
        if (this.ltngOut) {
            this.severity = severity;
            this.title = cleanOpts.title;
            this.messages = cleanOpts.messages;
            this.resetAutoClear();
        } else {
            NotificationService.displayToastMessage(
                this,
                cleanOpts.messages.join(','),
                cleanOpts.title,
                severity
            );
        }
    }

    handleClose(event) {
        event.preventDefault();
        event.stopPropagation();
        this.clear();
    }

}