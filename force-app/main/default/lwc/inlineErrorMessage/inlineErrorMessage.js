import {api, LightningElement} from 'lwc';
import Labels from './labels';

export default class Inlineerrormessage extends LightningElement {

    @api errors = [];
    @api genericError;

    get errorMessages() {
        let err = this.errors;
        if ((typeof err !== "string") && !Array.isArray(err)) {
            err = JSON.stringify(err);
        }
        if (!Array.isArray(err)) {
            err = [err];
        }
        // remove inner html tags from text message and return errors array
        return err.map(e => e.replace(/(<([^>]+)>)/gi, " "));
    }

    get genericErrorMessage() {
        let genericError = this.genericError;
        if (this.genericError === undefined) {
            genericError = Labels.INF_REVIEW_ERRORS_ON_THIS_PAGE;
        }
        return genericError;
    }

}