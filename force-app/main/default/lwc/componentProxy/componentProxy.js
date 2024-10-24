import {api, track, LightningElement} from 'lwc';

export default class ComponentProxy extends LightningElement {
    @api open() {
        this.isOpen = true;
    }

    @api close() {
        this.isOpen = false;
    }

    @track isOpen;
}