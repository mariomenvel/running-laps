import 'package:flutter/material.dart';

/// Generic carousel for swiping between items with page indicators
class PatternCarousel<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final void Function(int index)? onPageChanged;
  final int initialPage;

  const PatternCarousel({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onPageChanged,
    this.initialPage = 0,
  });

  @override
  State<PatternCarousel<T>> createState() => _PatternCarouselState<T>();
}

class _PatternCarouselState<T> extends State<PatternCarousel<T>> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('No hay patrones disponibles'));
    }

    return Column(
      children: [
        // Page indicators
        if (widget.items.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: _currentPage > 0
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                  onPressed: _currentPage > 0
                      ? () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
                const SizedBox(width: 8),
                ...List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: _currentPage == index
                          ? LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withOpacity(0.7),
                              ],
                            )
                          : null,
                      color: _currentPage == index
                          ? null
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: _currentPage == index
                          ? [
                              BoxShadow(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: _currentPage < widget.items.length - 1
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                  onPressed: _currentPage < widget.items.length - 1
                      ? () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
              ],
            ),
          ),

        // PageView
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              widget.onPageChanged?.call(index);
            },
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return widget.itemBuilder(context, widget.items[index], index);
            },
          ),
        ),
      ],
    );
  }
}
