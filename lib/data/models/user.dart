import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// Автор поста. Содержит вложенные модели [Address] (с [Geo]) и [Company].
@JsonSerializable(checked: true, explicitToJson: true)
class User {
  const User({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.company,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final int id;
  final String name;
  final String? username;
  final String? email;
  final String? phone;
  final String? website;
  final Address? address;
  final Company? company;

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable(checked: true, explicitToJson: true)
class Address {
  const Address({this.street, this.suite, this.city, this.zipcode, this.geo});

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);

  final String? street;
  final String? suite;
  final String? city;
  final String? zipcode;
  final Geo? geo;

  Map<String, dynamic> toJson() => _$AddressToJson(this);
}

@JsonSerializable(checked: true)
class Geo {
  const Geo({this.lat, this.lng});

  factory Geo.fromJson(Map<String, dynamic> json) => _$GeoFromJson(json);

  final String? lat;
  final String? lng;

  Map<String, dynamic> toJson() => _$GeoToJson(this);
}

@JsonSerializable(checked: true)
class Company {
  const Company({required this.name, this.catchPhrase, this.bs});

  factory Company.fromJson(Map<String, dynamic> json) =>
      _$CompanyFromJson(json);

  final String name;
  final String? catchPhrase;
  final String? bs;

  Map<String, dynamic> toJson() => _$CompanyToJson(this);
}
