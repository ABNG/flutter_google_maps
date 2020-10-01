import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:geocoder/geocoder.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  GoogleMapController _controller;
  final Set<Marker> _myMarkers = HashSet<Marker>();
  Set<Circle> _myCircle = HashSet<Circle>();
  Uuid uuid = Uuid();
  BitmapDescriptor _markerIcon; //custom marker icon
  StreamSubscription _locationSubscription; // from async library
  Location _locationTracker =
      Location(); // location package to get current location

  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setMarkerIcon();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("GOOGLE MAPS"),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialPosition,
        onMapCreated: (GoogleMapController controller) {
          controller.setMapStyle(Utils.mapStyles);
          _controller = controller;
        },
        markers: _myMarkers,
        circles: _myCircle,
        onTap: (LatLng coordinates) async {
          //marker on tap location
          _controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                  bearing: 192.8334901395799,
                  target: LatLng(coordinates.latitude, coordinates.longitude),
                  tilt: 59.440717697143555,
                  zoom: 19.151926040649414),
            ),
          );
          addMarkerOnTap(coordinates); // self descriptive
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
//          _controller.animateCamera(CameraUpdate.zoomOut());
          getCurrentLocation(); //get user current location
        },
        label: Text('To the lake!'),
        icon: Icon(Icons.directions_boat),
      ),
    );
  }

//this method contain LatLng
  void addMarkerOnTap(LatLng coordinates) async {
    // get address based on coordinates using geocoder package
    final coordinate =
        new Coordinates(coordinates.latitude, coordinates.longitude);
    List<Address> addresses =
        await Geocoder.local.findAddressesFromCoordinates(coordinate);
    Address first = addresses.first;
    setState(() {
      _myMarkers.clear(); // if you want only one marker
      _myMarkers.add(
        Marker(
          markerId: MarkerId(uuid.v4()),
          position: coordinates,
          infoWindow: InfoWindow(
            title: first.countryName,
            snippet: first.addressLine,
            anchor: Offset(0.3, 0.0),
          ),
          zIndex: 2,
          icon: _markerIcon,
        ),
      );
      _myCircle.clear();
    });
  }

//this method contain LocationData which can be converted to LatLng
  addMarker(LocationData coordinates) async {
    // get address based on coordinates using geocoder package
    final coordinate =
        new Coordinates(coordinates.latitude, coordinates.longitude);
    List<Address> addresses =
        await Geocoder.local.findAddressesFromCoordinates(coordinate);
    Address first = addresses.first;
    setState(() {
      _myMarkers.clear(); // if you want only one marker
      _myMarkers.add(
        Marker(
          markerId: MarkerId(uuid.v4()),
          position: LatLng(coordinates.latitude, coordinates.longitude),
          infoWindow: InfoWindow(
            title: first.countryName,
            snippet: first.addressLine,
          ),
          icon: _markerIcon,
          anchor: Offset(0.5, 0.5), //middle of circle
          rotation: coordinates.heading, // always icon see straight
          zIndex: 2, // how above on surface
          flat: true,
        ),
      );
      setCircle(coordinates);
    });
  }

//set custom marker
  void setMarkerIcon() async {
    _markerIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(), 'images/car_icon.png');
  }

  //set a circle
  void setCircle(LocationData coordinates) {
    _myCircle.clear();
    _myCircle.add(
      Circle(
        circleId: CircleId(uuid.v4()),
        center: LatLng(coordinates.latitude, coordinates.longitude),
        radius: coordinates.accuracy,
        zIndex: 1,
        strokeColor: Colors.blue,
        strokeWidth: 1,
        fillColor: Colors.blue.withAlpha(70),
      ),
    );
  }

  void getCurrentLocation() async {
    try {
      //show permission popup and get current location
      LocationData location = await _locationTracker.getLocation();
      print("lat: ${location.latitude} long: ${location.longitude}");
      _controller.animateCamera(CameraUpdate.newCameraPosition(
          new CameraPosition(
              bearing: 192.8334901395799,
              target: LatLng(location.latitude, location.longitude),
              tilt: 0,
              zoom: 18.00)));
      addMarker(location);

      //here we use stream to listen location change
      if (_locationSubscription != null) {
        _locationSubscription.cancel();
      }
      _locationSubscription =
          _locationTracker.onLocationChanged.listen((newLocalData) {
        if ((location.latitude + location.longitude) !=
            (newLocalData.latitude + newLocalData.longitude)) {
          // if old and new location same don't run if.
          location = newLocalData;
          if (_controller != null) {
            _controller.animateCamera(CameraUpdate.newCameraPosition(
                new CameraPosition(
                    bearing: 192.8334901395799,
                    target:
                        LatLng(newLocalData.latitude, newLocalData.longitude),
                    tilt: 0,
                    zoom: 18.00)));
            addMarker(newLocalData);
          }
        }
      });
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint("Permission Denied");
      }
    }
  }

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription.cancel(); //close the stream
    }
    super.dispose();
  }
}
class Utils {
  static String mapStyles = '''[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f5f5f5"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#f5f5f5"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#bdbdbd"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#eeeeee"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#e5e5e5"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#ffffff"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dadada"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#e5e5e5"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#eeeeee"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#c9c9c9"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  }
]''';
}
