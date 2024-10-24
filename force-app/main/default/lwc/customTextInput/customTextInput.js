import {LightningElement, api} from 'lwc';

export default class CustomTextInput extends LightningElement {

    @api editMode = false;
    @api value;
    @api rowId;
    @api colId;

    handleValueChange(event) {
        let currentValue = event.target.value;
        this.fireCellChangeEvent(currentValue);
    }

    fireCellChangeEvent(value) {
        const event = new CustomEvent('customcellchange', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                rowId: this.rowId,
                colId: this.colId,
                value: value
            }
        });
        this.dispatchEvent(event);
    }

}