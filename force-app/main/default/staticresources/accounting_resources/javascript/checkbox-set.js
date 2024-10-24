(function(window, document, $, ASModule) {
    "use strict";

    ASModule.CheckBoxSet = function(options) {
        this.call('init', options);
    };

    ASModule.CheckBoxSet.prototype.rebind = function() {
        this.call("rebind");
    };

    ASModule.CheckBoxSet.prototype.call = function(method) {
        if (this.methods[method]) {
            return this.methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
        }
        else {
            $.error('Method with name ' + method + ' not exist.');
        }
    };

   ASModule.CheckBoxSet.prototype.methods = {
        getStatus: function(targets) {
            var selectedCount = 0;
            targets.each(function() {
                if (this.checked) selectedCount++;
            });
            return (selectedCount >= targets.length);
        },
        setCheckedOne: function(target, checkedStatus) {
            var skipLockedDownLine = $(target).attr('disabled') === 'disabled';//disabled checkbox means Sales Tax Line
            if (!skipLockedDownLine) {
                target.checked = checkedStatus;
                if (checkedStatus) {
                    $(target).attr("checked", "checked");
                }
                else {
                    $(target).removeAttr("checked");
                }
            }
        },
        setChecked: function(targets, checkedStatus) {
            var inst = this;
            targets.each(function() {
                inst.call("setCheckedOne", this, checkedStatus);
            });
        },
        setCheckboxMainState: function(checkboxMain, checkboxes) {
            this.call("setChecked", checkboxMain, this.call("getStatus", checkboxes));
        },
        init: function(options) {
            this.settings = $.extend(true, {
                selectors: {
                    main: false,
                    child: false
                },
                methods: {
                    load: false,
                    click: false
                }
            }, options);
            if (this.settings.methods.load) {
                this.settings.methods.load.call(this);
            }
            this.call('rebind');
        },
        rebind: function() {
            var inst = this;
            if (inst.settings.selectors.main && inst.settings.selectors.child) {
                var checkBoxMain = $(inst.settings.selectors.main);
                var checkBoxes = $(inst.settings.selectors.child);
                if (checkBoxMain && checkBoxMain.length >= 1 && checkBoxes && checkBoxes.length >= 1) {
                    var eClick = inst.settings.methods.click;
                    var eRebind = inst.settings.methods.rebind;
                    var eUpdate = inst.settings.methods.update;
                    checkBoxMain.bind("click", function(event) {
                        ASModule.toggleSpinner(true);
                        setTimeout(function() {
                            inst.call("setChecked", checkBoxes, event.target.checked);
                            inst.call("setChecked", checkBoxMain, event.target.checked);
                            if (eClick) {
                                checkBoxes.each(function(index) {
                                    eClick(this);
                                });
                                if (eUpdate) {
                                    eUpdate();
                                }
                            }
                            ASModule.toggleSpinner(false);
                        }, 10);
                    });
                    checkBoxes.bind("click", function(event) {
                        inst.call("setCheckboxMainState", checkBoxMain, checkBoxes);
                        if (eClick) {
                            eClick(event.target);
                            if (eUpdate) {
                                eUpdate();
                            }
                        }
                    });
                    inst.call("setCheckboxMainState", checkBoxMain, checkBoxes);
                    if (eClick) {
                        checkBoxes.each(function(index) {
                            eClick(this);
                        });
                        if (eUpdate) {
                            eUpdate();
                        }
                    }
                    if (eRebind) {
                        eRebind.call(this);
                    }
                }
                else {
                    console.error("Set selectors.main and selectors.child options for correct working.");
                }
            }
        }
    };
})(window, document, $j, AcctSeed.ASModule);