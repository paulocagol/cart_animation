import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'product.dart';

Future<void> main() async {
  runApp(DevicePreview(
    enabled: true,
    builder: (context) => const App(),
  ));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Device Preview Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ShopPage(),
    );
  }
}

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with TickerProviderStateMixin {
  final GlobalKey _cartKey = GlobalKey();
  final GlobalKey _deviceFrameKey = GlobalKey();
  final List<Product> _cartItems = [];
  final List<Product> _products = List.generate(
    30,
    (index) => Product(
      id: 'Product $index',
      image: 'assets/img.png',
      key: GlobalKey(debugLabel: 'Product $index'),
    ),
  );
  final Map<Product, GlobalKey> _cartItemKeys = {};
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  final List<OverlayEntry> _overlayEntries = [];
  final List<AnimationController> _controllers = [];
  final Set<Product> _animatingItems = {};
  Offset _imageOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _scrollToItem(GlobalKey key) async {
    final context = key.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        curve: Curves.fastOutSlowIn,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    }
  }

  Future<void> _addToCart(Product product) async {
    if (_animatingItems.contains(product)) return;

    final productContext = product.key.currentContext;
    final cartContext = _cartKey.currentContext;
    final deviceFrameContext = _deviceFrameKey.currentContext;

    if (productContext != null && cartContext != null && deviceFrameContext != null) {
      RenderBox productRenderBox = productContext.findRenderObject() as RenderBox;
      final RenderBox deviceFrameRenderBox = deviceFrameContext.findRenderObject() as RenderBox;

      _imageOffset = productRenderBox.localToGlobal(Offset.zero, ancestor: deviceFrameRenderBox);
      final RenderBox cartRenderBox = cartContext.findRenderObject() as RenderBox;

      if (_cartItems.contains(product)) {
        var cartItem = _cartItemKeys[product]!;

        if (cartItem.currentContext == null) {
          // Aproximar o scroll até a posição do item
          final itemIndex = _cartItems.indexOf(product);
          final targetPosition = (itemIndex * 50.0).clamp(0.0, _scrollController.position.maxScrollExtent);
          await _scrollController.animateTo(
            targetPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          cartItem = _cartItemKeys[product]!;
          print('cartItem: $cartItem');
        }

        await _scrollToItem(cartItem);

        _targetOffset = (cartItem.currentContext?.findRenderObject() as RenderBox?)
                ?.localToGlobal(Offset.zero, ancestor: deviceFrameRenderBox) ??
            _targetOffset;

        _animateItemToCart(product, productRenderBox);
      } else {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _targetOffset = cartRenderBox.localToGlobal(Offset.zero, ancestor: deviceFrameRenderBox);
        _animateItemToCart(product, productRenderBox);
        _addItemToCart(product);
        setState(() {});
      }
    }
  }

  void _addItemToCart(Product product) {
    final GlobalKey itemKey = GlobalKey();
    _cartItemKeys[product] = itemKey;
    _cartItems.insert(0, product);
    _listKey.currentState?.insertItem(0);
  }

  void _animateItemToCart(Product product, RenderBox productRenderBox) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final offsetAnimation = Tween<Offset>(
      begin: _imageOffset,
      end: _targetOffset,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    final sizeAnimation = Tween<double>(
      begin: productRenderBox.size.width,
      end: 50,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));

    final overlayEntry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: offsetAnimation,
        builder: (context, child) {
          return Positioned(
            left: offsetAnimation.value.dx,
            top: offsetAnimation.value.dy,
            child: AnimatedBuilder(
              animation: sizeAnimation,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.asset(
                    'assets/img.png',
                    fit: BoxFit.cover,
                    width: sizeAnimation.value,
                    height: sizeAnimation.value,
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    _overlayEntries.add(overlayEntry);
    Overlay.of(context).insert(overlayEntry);
    _controllers.add(controller);
    _animatingItems.add(product);

    sizeAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final entryIndex = _overlayEntries.indexOf(overlayEntry);
        if (entryIndex != -1) {
          _overlayEntries[entryIndex].remove();
          _overlayEntries.removeAt(entryIndex);
        }
        controller.dispose();
        _controllers.remove(controller);
        _animatingItems.remove(product);
        setState(() {});
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _deviceFrameKey,
      appBar: AppBar(
        title: const Text('Shopping App'),
      ),
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.0,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return GestureDetector(
                onTap: () {
                  _addToCart(product);
                },
                child: GridTile(
                  footer: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12.0),
                      bottomRight: Radius.circular(12.0),
                    ),
                    child: GridTileBar(
                      backgroundColor: Colors.black54,
                      title: Text(product.id),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_shopping_cart),
                        color: Colors.white,
                        onPressed: () {
                          _addToCart(product);
                        },
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.asset(
                      product.image,
                      fit: BoxFit.cover,
                      key: product.key,
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: BottomAppBar(
              child: SizedBox(
                height: 100,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        key: _cartKey,
                        child: AnimatedList(
                          key: _listKey,
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          initialItemCount: _cartItems.length,
                          itemBuilder: (context, index, animation) {
                            final item = _cartItems[index];
                            final originalIndex = _products.indexWhere((product) => product == item);
                            return Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizeTransition(
                                sizeFactor: animation,
                                axis: Axis.horizontal,
                                child: Opacity(
                                  opacity: _animatingItems.contains(item) ? 0 : 1,
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12.0),
                                          child: Image.asset(
                                            'assets/img.png',
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            key: _cartItemKeys[item],
                                          ),
                                        ),
                                        Positioned(
                                          top: 4.0,
                                          left: 4.0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2.0),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(4.0),
                                            ),
                                            child: Text(
                                              '$originalIndex',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.0,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Stack(
                          children: [
                            const Icon(Icons.shopping_cart, size: 40),
                            if (_cartItems.isNotEmpty)
                              Positioned(
                                right: 0,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.red,
                                  child: Text(
                                    '${_cartItems.length}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
