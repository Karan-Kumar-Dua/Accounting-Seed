import {api, LightningElement} from 'lwc';

export default class WizardItem extends LightningElement {
    @api validateAndRetrieve() {
        return {isValid: true, data: {}};
    }

    @api set values(values) {
        this._values = values;
    }
    get values() {
        return this._values;
    }
}