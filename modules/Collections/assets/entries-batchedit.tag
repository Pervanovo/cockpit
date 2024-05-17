<entries-batchedit>

    <style>
        .field-container {
            transition: all 0.3s ease-in-out;
        }
    </style>

    <div ref="modal" class="uk-modal">

        <div class="uk-modal-dialog uk-modal-dialog-large uk-form">

            <h3 class="uk-text-bold uk-flex uk-flex-middle">{ App.i18n.get('Batch edit') } <span class="uk-badge uk-margin-left">{selected.length} { App.i18n.get(selected.length == 1 ? 'Entry' : 'Entries') }</span></h3>

            <div class="uk-margin-top uk-overflow-container uk-panel-space" if="{!blocked}">

                <div class="field-container uk-panel uk-margin {checked[field.name] && 'uk-panel-box uk-panel-card'}" each="{field in _fields}">
                    <div class="uk-grid">
                        <div class="uk-width-1-4">
                            <div class="uk-flex uk-flex-middle {field.$lang && 'uk-margin-left'}">
                                <input class="uk-checkbox uk-margin-right" type="checkbox" onclick="{parent.toggleCheck}">
                                <div>
                                    <span class="{parent.checked[field.name] ? 'uk-text-bold':'uk-text-muted'}" show="{!field.$lang}">{field.label || field.name}</span>
                                    <span class="uk-badge uk-badge-outline uk-margin-small-right {parent.checked[field.name] ? 'uk-text-bold':'uk-text-muted'}" if="{field.localize}" title="{field.label || field.name}" data-uk-tooltip="pos:'right'">{field.$lang ? field.$lang.code : App.$data.languageDefaultLabel}</span>
                                    <div class="uk-margin-top uk-text-small uk-text-muted" show="{field.info && !field.$lang}">{ field.info}</div>
                                </div>
                            </div>
                        </div>
                        <div class="uk-flex-item-1" if="{parent.checked[field.name]}">
                            <cp-field type="{field.type || 'text'}" bind="_entry.{ field.name }" opts="{ field.options || {} }"></cp-field>
                        </div>
                    </div>

                </div>

            </div>

            <div class="uk-modal-footer uk-text-right">
                <button class="uk-button uk-button-link uk-button-large" show="{Object.keys(_entry).length}" onclick="{ save }">{ App.i18n.get('Save') }</button>
                <button class="uk-button uk-button-link uk-button-large uk-modal-close">{ App.i18n.get('Cancel') }</button>
            </div>
        </div>

    </div>

    <cp-preloader-fullscreen show="{ blocked }"></cp-preloader-fullscreen>

    <script>

        this.mixin(RiotBindMixin);

        var $this = this;

        this.modal     = null;
        this.collection= opts.collection || {};
        this.fields    = opts.fields || {};
        this.languages = App.$data.languages;
        this.entries   = [];
        this.selected  = [];

        this.checked = {};
        this._entry  = {};
        this._fields = [];
        this.blocked = false;

        var field = null;

        Object.keys(this.fields).forEach(function(name) {

            if (['_created', '_modified'].indexOf(name) != -1) return;

            field = App.$.extend({}, $this.fields[name]);
            $this._fields.push(field);

            if (field.localize && $this.languages.length) {

                $this.languages.forEach(function(lng){
                    field = App.$.extend({}, $this.fields[name]);
                    field.name = $this.fields[name].name+'_'+lng.code;
                    field.$lang = lng;
                    $this._fields.push(field);
                });
            }
        });

        this.on('mount', function() {

            this.modal = UIkit.modal(this.refs.modal, {modal:false});

            this.modal.on('hide.uk.modal', function(e) {

                if (e.target === $this.refs.modal) {
                    $this.checked = {};
                    $this._entry = {};
                    $this.entries = [];
                    $this.selected = [];
                    $this.update();
                }

            })
        });

        this.toggleCheck = function(e) {

            this.checked[e.item.field.name] = e.target.checked;

            if (!this.checked[e.item.field.name]) {
                delete this.checked[e.item.field.name]
            }

            if (!e.target.checked && (e.item.field.name in this._entry)) {

                delete this._entry[e.item.field.name];

                if ((e.item.field.name+'_slug') in this._entry) {
                    delete this._entry[e.item.field.name+'_slug'];
                }
            }
        }

        this.open = function(selected) {
            this.blocked = true;
            this.selected = selected;
            var ids = [];
            for (var id of selected) {
                ids.push({_id: id});
            }
            var data = {
                collection: this.collection.name,
                options: {
                    filter: {
                        "$or": ids
                    },
                    limit: selected.length
                }
            };
            App.request('/collections/_find', data).then(function(response){
                if(response.length < selected.length) {
                    App.ui.notify("Could not find all selected entries, try again!", "danger");
                } else {
                    $this.entries = response;
                    $this.modal.show();
                }
            }).catch(function(reason){
                console.error(reason);
                App.ui.notify("Something went wrong!", "danger");
            }).finally(function(){
                $this.blocked = false;
                $this.update();
            });
        }

        this.save = function() {

            var required = [], field;

            Object.keys(this.checked).forEach(function(name){
                field = _.find($this._fields, {name: name});

                if (field.required && !$this._entry[field.name]) {

                    if (!(field.name in $this._entry) || !($this._entry[field.name]===false || $this._entry[field.name]===0)) {
                        required.push(field.label || field.name);
                    }
                }
            });

            if (required.length) {
                App.ui.notify([
                    App.i18n.get('Fill in these required fields before saving:'),
                    '<div class="uk-margin-small-top">'+required.join(',')+'</div>'
                ].join(''), 'danger');
            } else {
                this.applyBatchEdit(this._entry);
                this.modal.hide();
            }

        }

        this.applyBatchEdit = function(data) {

            var promises = [], ids = [], _filter = function(list) {

                var filtered = [];

                list.forEach(function (entry) {

                    if ($this.selected.indexOf(entry._id) > -1) {
                        filtered.push(entry);
                    }

                    if (entry.children && entry.children.length) {
                        filtered = filtered.concat(_filter(entry.children))
                    }
                });

                return filtered;
            };

            _filter(this.entries).forEach(function(entry) {

                if ($this.selected.indexOf(entry._id) > -1) {

                    _.extend(entry, data);

                    var tmpEntry = _.extend({}, entry);

                    if (tmpEntry.children) {
                        delete tmpEntry.children;
                    }

                    var p = App.request('/collections/save_entry/'+$this.collection.name, {entry:tmpEntry});
                    promises.push(p);
                    ids.push(tmpEntry._id);
                }
            });

            if (promises.length > 0) {
                var done = 0;

                App.ui.block('<h1>Updating...</h1><div id="batch-progress" class="uk-active uk-progress uk-progress-striped"><div class="uk-progress-bar"></div></div>');
                promises.forEach(function(p){
                   p.finally(function(){
                       $('#batch-progress .uk-progress-bar').css("width", 100*++done/promises.length + "%");
                   });
                });

                Promise.allSettled(promises).then(function(results){
                    var rejected = [];
                    for (var i=0; i < results.length; i++) {
                        var id = ids[i];
                        var result = results[i];
                        if (result.status !== "fulfilled") {
                            rejected.push('<li class="uk-text-danger"><a target="_blank" href="/collections/entry/' + $this.collection.name + '/' + id + '">' + id + '</a>: ' + JSON.stringify(result.reason) + '</li>');
                        }
                    }
                    App.ui.unblock();
                    var body = rejected.length > 0 ? '<h2 class="uk-text-warning">Had some errors (' + rejected.length + ' of ' + promises.length + '):</h2>' : '<h1 class="uk-text-success">Great success!</h1>';
                    body += rejected.length > 0 ? ('<ul>' + rejected.join('') + '</ul>') : '';
                    body += '<p class="uk-text-bold"><a onclick="window.location.reload()">Reload the page</a> to see updated entries!</p>';
                    body = '<div>' + body + '</div>';
                    App.ui.block(body);
                });
            }

            this.update();
        }

    </script>

</entries-batchedit>
