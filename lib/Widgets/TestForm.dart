import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_select/smart_select.dart';

import 'package:acestat/Analysis/CrabTest.dart';
import 'package:acestat/Analysis/TestDefinitions.dart';
import 'package:acestat/Analysis/TestFormState.dart';
import 'package:acestat/Analysis/TestHandler.dart';

/// A widget that generates the test form based on test definitions.
class TestForm extends StatefulWidget {
  final Function(CrabTest) onSubmit;

  TestForm({@required this.onSubmit});

  @override
  State<StatefulWidget> createState() => _TestFormState();
}

/// Holds the state for a TestForm.
class _TestFormState extends State<TestForm> {
  Map<String, Map<String, TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = Map<String, Map<String, TextEditingController>>();
  }

  /// Ensure disposal of TextEditingControllers on instance disposal.
  @protected
  @mustCallSuper
  void dispose() {
    _controllers.values.forEach(
        (map) => map.values.forEach((controller) => controller.dispose()));
    super.dispose();
  }

  /// Build the test parameter form from the available test definitions.
  List<Widget> _buildForm(context) {
    TestFormState form = Provider.of<TestFormState>(context);
    List<TableRow> _rows = [];

    List _presets = form.presets.keys.toList();
    _presets.insert(0, "");

    /// Load the presets dropdown.
    _rows.add(TableRow(children: [
      Text("Presets:"),
      DropdownButton<String>(
          onTap: () => FocusScope.of(context).unfocus(),
          value: form.preset ?? "",
          isExpanded: true,
          onChanged: (selectedChoice) {
            if (selectedChoice.isNotEmpty) {
              form.preset = selectedChoice;
              _controllers[form.selectedTest]
                  .forEach((key, value) => value.text = form[key]);
            }
          },
          style: Theme.of(context).textTheme.bodyText2,
          items: _presets
              .map<DropdownMenuItem<String>>((key) => DropdownMenuItem<String>(
                    value: key,
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Text(key),
                    ),
                  ))
              .toList())
    ]));

    /// Generate the parameters portion of the form.
    form.info["parameters"].forEach((pKey, param) {
      Widget _input;
      if (param["type"] == "select") {
        _input = DropdownButton<String>(
            onTap: () => FocusScope.of(context).unfocus(),
            value: form[pKey],
            isExpanded: true,
            onChanged: (selectedChoice) {
              form[pKey] = selectedChoice;
            },
            style: Theme.of(context).textTheme.bodyText2,
            items: param["options"]
                .entries
                .map<DropdownMenuItem<String>>(
                    (entry) => DropdownMenuItem<String>(
                        value: entry.key,
                        child: Container(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              child: Text(entry.value),
                              fit: BoxFit.contain,
                            ))))
                .toList());
      } else if (param["type"] == "int") {
        // Have to use text editing controller to filter number input
        _controllers.putIfAbsent(
            form.selectedTest, () => Map<String, TextEditingController>());
        _controllers[form.selectedTest]
            .putIfAbsent(pKey, () => TextEditingController(text: form[pKey]));
        bool signed = param["signed"] != null && param["signed"];
        _input = TextFormField(
            textAlign: TextAlign.right,
            keyboardType:
                TextInputType.numberWithOptions(signed: signed, decimal: false),
            onChanged: (value) {
              form[pKey] = value;
            },
            controller: _controllers[form.selectedTest][pKey],
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(signed ? r'^-?[0-9]*$' : r'^[0-9]*$')),
            ],
            decoration: InputDecoration(
                hintText:
                    param["min"].toString() + "-" + param["max"].toString(),
                errorText:
                    validateParameter(form.selectedTest, pKey, form[pKey])));
      }
      List<Widget> _row = [];
      _row.add(Expanded(
          child: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(
            left: 10.0), //EdgeInsets.symmetric(horizontal: 10.0),
        child: _input,
      )));
      if (param["units"] != null) {
        _row.add(Text(param["units"]));
      }
      _rows.add(
          TableRow(children: [Text(param["name"] + ":"), Row(children: _row)]));
    });

    return [
      AbsorbPointer(
          absorbing: !form.enabled,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Table(
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: {0: IntrinsicColumnWidth()},
                children: _rows),
          )),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        ElevatedButton(
          child: Text("Submit"),
          onPressed: form.enabled
              ? () {
                  try {
                    widget.onSubmit(form.test);
                  } catch (e) {}
                }
              : null,
        ),
        ElevatedButton(
          child: Text("Send Cancel"),
          onPressed: () {
            TestHandler().reset();
          },
        )
      ])
    ];
  }

  @override
  Widget build(BuildContext context) {
    TestFormState form = Provider.of<TestFormState>(context);
    return Column(children: [
      AbsorbPointer(
          absorbing: !form.enabled,
          child: SmartSelect<String>.single(
              title: 'Analysis Technique',
              placeholder: 'Choose one',
              choiceStyle: S2ChoiceStyle(
                titleStyle: Theme.of(context)
                    .textTheme
                    .subtitle1
                    .copyWith(fontWeight: FontWeight.normal),
                color: Theme.of(context).textTheme.subtitle1.color,
                activeColor: Theme.of(context).textTheme.subtitle1.color,
              ),
              value: form.selectedTest,
              onChange: (state) {
                form.selectedTest = state.value;
              },
              choiceItems: S2Choice.listFrom(
                source: TestDefinitions().tests.values.toList(growable: false),
                value: (index, item) => item['id'],
                title: (index, item) => item['name'],
                // group: (index, item) => item['technique'],
              ),
              // choiceGrouped: true,
              modalType: S2ModalType.popupDialog,
              tileBuilder: (context, state) {
                return S2Tile(
                  title: state.titleWidget,
                  value: state.valueDisplay,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    state.showModal();
                  },
                  isTwoLine: true,
                );
              })),
      ..._buildForm(context),
    ]);
  }
}
