function handleDataChange(self, evt, index=undefined) {
    
    self.dispatchEvent(new CustomEvent('datachange', {
        bubbles: true,
        detail: {
            name: evt.target.dataset.field,
            type: evt.target.type,
            value: evt.target.value,
            checked: evt.target.checked,
            index : index
    }}));
}
function isValid(self) {
    const inputs = self.template.querySelectorAll('lightning-input,lightning-combobox');

    let isValid = true;
    let data = {};
    inputs && inputs.forEach(input => {
        if(!input.checkValidity()) {
            isValid = false;
        } else {
            input.setCustomValidity('');
        }
        input.reportValidity();
    });

    return {isValid, data};
}
export { handleDataChange,isValid };