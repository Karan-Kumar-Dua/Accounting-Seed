import { LightningElement, api } from 'lwc';
import { LabelService } from 'c/utils';

export default class Modal extends LightningElement {
    @api title;
    @api tagline;
    @api show;
    @api sectionCss = '';
    @api crossNotVisible = false;
    labels = LabelService;

    connectedCallback(){
    }

    get isTaglineTitleNull(){
        return this.title != null || this.tagLine != null;
    }
    get titleNotNull(){
        return this.title != null;
    }
    get taglineNotNull(){
        return this.tagline != null;
    }
    close(){
        this.show = false;
        const close = new CustomEvent('closeaction', {
            detail: {
                data: false,
                },
                bubbles: true,
                composed: true
            });
        this.dispatchEvent(close);
    }
}