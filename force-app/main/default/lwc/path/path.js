import {LightningElement, api, track} from 'lwc';
import {CommonUtils} from 'c/utils';
import Labels from './labels';

export default class Path extends LightningElement {
    labels = Labels;
    @api goToItem(pathItemId) {
        this.items = this.items.map(item => ({
            ...item,
            isActive: item.id === pathItemId,
            isCurrent: item.id === pathItemId
        }));
    }

    @api set items(items) {
        this._items = items && this.presetFlagsAndClasses(items);
    }
    get items() {
        return this._items;
    }

    @track _items;

    handleItemClick(event) {
        this.dispatchEvent(new CustomEvent('itemclick', {detail: {value: event.currentTarget.dataset.id}}));
    }

    presetFlagsAndClasses(items) {
        if(items) {
            const activeItemIndex = items.findIndex(item => item.isActive);
            const currentItemIndex = items.findIndex(item => item.isCurrent);

            items = items
                .map((item, index) => ({ //preset flags
                    ...item,
                    isActive: (!~activeItemIndex && !index) || index === activeItemIndex,
                    isCurrent: (!~currentItemIndex && (!~activeItemIndex && !index || index === activeItemIndex)) || index === currentItemIndex,
                    isComplete: index < activeItemIndex
                }))
                .map(item => ({ //preset classes
                    ...item,
                    containerClasses: CommonUtils.computeClasses([
                        'slds-path__item',
                        item.isComplete && 'slds-is-complete',
                        item.isActive && 'slds-is-active',
                        item.isCurrent && 'slds-is-current',
                        !item.isComplete && !item.isActive && 'slds-is-incomplete'
                    ])
                }));
        }
        return items
    }
}