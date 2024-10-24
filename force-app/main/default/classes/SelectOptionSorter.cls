public with sharing class SelectOptionSorter {

    //Sort field to use in SelectOption i.e. Label or Value
    public enum FieldToSort {
        Label, Value
    }

    public static void doSort(List<SelectOption> opts, FieldToSort sortField) {

        if (opts == NULL || opts.isEmpty()) {
            return;
        }

        Map<String, SelectOption> mapping = new Map<String, SelectOption>();
        // Suffix to avoid duplicate values like same labels or values are in inbound list
        Integer suffix = 1;
        for (SelectOption opt : opts) {
            if (sortField == FieldToSort.Label) {
                mapping.put((opt.getLabel() + suffix++), opt);
            } else {
                mapping.put((opt.getValue() + suffix++), opt);
            }
        }

        List<String> sortKeys = new List<String>();
        sortKeys.addAll(mapping.keySet());
        sortKeys.sort();
        // clear the original collection to rebuilt it
        opts.clear();

        for (String key : sortKeys) {
            opts.add(mapping.get(key));
        }
    }

}