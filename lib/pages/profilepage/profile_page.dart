import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  
  

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              child: Row(
                children: [
                  Text(
                    'Your Performance',
                    style: TextStyle(
                        fontSize: 26,
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Spacer(),
                  Text(
                    'Name: John Doe\nEmail: john.doe@example.com',
                    style: TextStyle(
                        fontSize: 16, color: Color.fromARGB(255, 0, 0, 0)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 20),
                  const Icon(
                    Icons.account_circle,
                    size: 50,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
            ),
            Spacer(),
              Row(
                  children: [
                   
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: PieChart(
                          
                          PieChartData(
                            centerSpaceColor: Colors.deepPurple,
                            sections: [
                              PieChartSectionData(
                                value: 40,
                                color: Colors.red,
                                title: 'Underate',
                                radius: 50,
                                titleStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              PieChartSectionData(
                                value: 30,
                                color: Colors.green,
                                title: 'Achieved',
                                radius: 50,
                                titleStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                              PieChartSectionData(
                                value: 20,
                                color: Colors.orange,
                                title: 'Overate',
                                radius: 50,
                                titleStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                              ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      Spacer(),
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      const style = TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      );
                                      Widget text;
                                      switch (value.toInt()) {
                                        case 1:
                                          text = const Text('Mon', style: style);
                                          break;
                                        case 2:
                                          text = const Text('Tue', style: style);
                                          break;
                                        case 3:
                                          text = const Text('Wed', style: style);
                                          break;
                                        case 4:
                                          text = const Text('Thu', style: style);
                                          break;
                                        case 5:
                                          text = const Text('Fri', style: style);
                                          break;
                                        case 6:
                                          text = const Text('Sat', style: style);
                                          break;
                                        case 7:
                                          text = const Text('Sun', style: style);
                                          break;
                                        default:
                                          text = const Text('');
                                      }
                                      return SideTitleWidget(
                                        meta: meta,
                                        space: 4,
                                        child: text,
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              // Used GitHub CoPilot to generate the code structure for the bar chart titles, 16/03/2025
                              barGroups: [
                                BarChartGroupData(x: 1, barRods: [
                                  BarChartRodData(
                                      toY: 2550, color: Colors.blueAccent)
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                                BarChartGroupData(x: 2, barRods: [
                                  BarChartRodData(
                                      toY: 1500, color: Colors.greenAccent)
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                                BarChartGroupData(x: 3, barRods: [
                                  BarChartRodData(
                                      toY: 2310, color: Colors.orangeAccent)
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                                BarChartGroupData(x: 4, barRods: [
                                  BarChartRodData(
                                      toY: 2015, color: const Color.fromARGB(255, 255, 64, 64))
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                                BarChartGroupData(x: 5, barRods: [
                                  BarChartRodData(
                                      toY: 2310, color: const Color.fromARGB(255, 255, 64, 210))
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                                BarChartGroupData(x: 6, barRods: [
                                  BarChartRodData(
                                      toY: 2310, color: const Color.fromARGB(255, 223, 255, 64))
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                                BarChartGroupData(x: 7, barRods: [
                                  BarChartRodData(
                                      toY: 2310, color: const Color.fromARGB(255, 64, 226, 255))
                                ], showingTooltipIndicators: [
                                  0
                                ]),
                              ],
                            )
                                            ),
                      )
                    
                  ],
                ),
                Spacer(),
              
            
            Text(
              'If you keep it up, you\'ll hit your weight goal in roughly ... days!',
              style: TextStyle(
                  fontSize: 24,
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              selectionColor: Color.fromARGB(255, 12, 196, 8),
            ),
            Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                      onPressed: () {},
                      backgroundColor:
                          const Color.fromARGB(255, 142, 97, 219),
                      child: const Icon(Icons.settings)),
                  Spacer(),
                  FloatingActionButton(
                    onPressed: () {},
                    backgroundColor:
                        const Color.fromARGB(255, 0, 198, 238),
                    child: const Icon(Icons.toggle_off),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}    //Used GitHub CoPilot to fix parentheses issue and sizing of widgets, 14/03/2025
