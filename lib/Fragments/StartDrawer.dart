import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acestat/Resources/PackageInfo.dart';
import 'package:acestat/Fragments/ResultBrowser.dart';
import 'package:acestat/Resources/Styles.dart';
import 'package:acestat/Transitions/Slide.dart';
import 'package:acestat/Analysis/TestHistoryState.dart';

/// Builds the drawer for the starting app screen.
class StartDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle textStyle = theme.textTheme.bodyText2;
    return Container(
        width: min(350, MediaQuery.of(context).size.width * 0.9),
        child: Drawer(
          child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(children: <Widget>[
                Container(
                  width: double.infinity,
                  child: DrawerHeader(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Image.asset("assets/images/usace_castle.png"),
                    decoration: BoxDecoration(color: usaceRed),
                  ),
                ),
                Expanded(
                    child: ListView(
                        padding: EdgeInsets.zero,
                        children:
                            ListTile.divideTiles(context: context, tiles: [
                          // ListTile(
                          //   title: Text(
                          //     "Connect to Device",
                          //     textAlign: TextAlign.center,
                          //   ),
                          //   onTap: () {},
                          // ),
                          ListTile(
                            title: Text(
                              "Result Browser",
                              textAlign: TextAlign.center,
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                  context,
                                  SlideLeftRoute(
                                      page: MultiProvider(providers: [
                                    ChangeNotifierProvider(
                                        create: (_) => TestHistoryState())
                                  ], child: new ResultBrowser())));
                            },
                          ),
                          ListTile(
                            title: Text(
                              "Tools",
                              textAlign: TextAlign.center,
                            ),
                            enabled: false,
                            onTap: () {},
                          ),
                          ListTile(
                            title: Text(
                              "Settings",
                              textAlign: TextAlign.center,
                            ),
                            enabled: false,
                            onTap: () {},
                          ),
                          // ListTile(
                          //   title: Text(
                          //     "About",
                          //     textAlign: TextAlign.center,
                          //   ),
                          //   enabled: false,
                          //   onTap: () {},
                          // ),
                        ]).toList()
                        // Review Previous Results
                        // Settings
                        // Other tools/features (update?)
                        )),
                AboutListTile(
                  icon: const Icon(Icons.info),
                  applicationIcon: Image.asset(
                    "assets/images/usace_castle.png",
                    height: 60,
                  ),
                  applicationName: PackageInfo.appName,
                  applicationVersion: PackageInfo.version,
                  applicationLegalese: PackageInfo.legalese,
                  aboutBoxChildren: <Widget>[
                    const SizedBox(height: 24),
                    RichText(
                      text: TextSpan(
                          text: PackageInfo.description, style: textStyle),
                    ),
                  ],
                ),
              ])),
        ));
  }
}
