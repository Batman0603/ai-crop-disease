import '../models/disease_information.dart';

class DiseaseInformationService {
  DiseaseInformationService._();

  static const Map<int, DiseaseInformation> _diseases = {
    // Apple
    0: DiseaseInformation(
      classIndex: 0,
      className: 'Apple___Apple_scab',
      crop: 'Apple',
      diseaseName: 'Apple Scab',
      description:
          'A fungal disease that causes olive-green to brown leaf spots and '
          'rough corky lesions on fruit. Severe infections can cause leaf '
          'drop and deformed or cracked fruit.',
      symptoms: [
        'Olive-green to brown irregular leaf spots',
        'Leaf spots become darker as they age',
        'Brown raised corky spots on fruit',
        'Severely affected fruit may become deformed or cracked',
        'Premature leaf drop can occur in severe infections',
      ],
      treatment: [
        'Remove and destroy fallen infected leaves to reduce overwintering inoculum.',
        'Maintain good orchard sanitation and remove heavily diseased material.',
        'Choose disease-resistant apple cultivars where practical.',
        'Improve canopy airflow and reduce prolonged leaf wetness.',
        'Use locally registered fungicides according to the current crop label when disease pressure warrants them.',
      ],
      isHealthy: false,
    ),

    1: DiseaseInformation(
      classIndex: 1,
      className: 'Apple___Black_rot',
      crop: 'Apple',
      diseaseName: 'Black Rot',
      description:
          'A fungal disease that can affect apple leaves, fruit and branches. '
          'Fruit may develop brown ringed lesions and remain firm as it rots, '
          'while infected fruit can become mummified.',
      symptoms: [
        'Round leaf spots with a purple border and tan center',
        'Brown fruit lesions that may develop concentric rings',
        'Firm fruit rot followed by fruit mummification',
        'Sunken or cracked branch cankers',
        'Wilting and death of leaves on girdled branches',
      ],
      treatment: [
        'Remove mummified fruit and diseased plant material from the tree and orchard.',
        'Prune out diseased or dead wood where appropriate.',
        'Avoid unnecessary tree stress and manage wounds carefully.',
        'Maintain good orchard sanitation to reduce sources of infection.',
        'Use locally registered disease-management products only when appropriate and according to their label.',
      ],
      isHealthy: false,
    ),

    2: DiseaseInformation(
      classIndex: 2,
      className: 'Apple___Cedar_apple_rust',
      crop: 'Apple',
      diseaseName: 'Cedar-Apple Rust',
      description:
          'A rust disease requiring both apple-family hosts and cedar or '
          'juniper hosts to complete its life cycle. Apple leaves develop '
          'yellow to orange-red spots, sometimes with structures on the lower '
          'leaf surface.',
      symptoms: [
        'Yellow leaf spots that become bright orange-red',
        'Red borders around mature leaf spots',
        'Small dark structures on the upper leaf surface',
        'Fringed tube-like structures on the underside of leaves',
        'Occasional rough green or brown fruit spots',
      ],
      treatment: [
        'Plant resistant apple cultivars where available.',
        'Remove infected or diseased plant material when practical.',
        'Inspect nearby junipers or cedars for rust galls and prune affected material where appropriate.',
        'Reduce prolonged leaf wetness and maintain good canopy airflow.',
        'Use preventive disease-management products only when locally appropriate and legally registered.',
      ],
      isHealthy: false,
    ),

    3: DiseaseInformation(
      classIndex: 3,
      className: 'Apple___healthy',
      crop: 'Apple',
      diseaseName: 'Healthy Apple',
      description:
          'No disease pattern corresponding to the trained disease classes '
          'was identified for this healthy class.',
      symptoms: [],
      treatment: [
        'Continue regular monitoring for leaf, fruit and branch abnormalities.',
        'Maintain balanced irrigation and nutrition.',
        'Prune appropriately to maintain canopy airflow.',
        'Remove fallen or diseased plant material during routine orchard sanitation.',
      ],
      isHealthy: true,
    ),

    // Corn
    4: DiseaseInformation(
      classIndex: 4,
      className: 'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
      crop: 'Corn',
      diseaseName: 'Gray Leaf Spot',
      description:
          'A fungal leaf disease that produces gray to tan lesions and can '
          'reduce photosynthetic leaf area when disease becomes severe.',
      symptoms: [
        'Gray to tan rectangular or elongated leaf lesions',
        'Lesions often develop parallel to leaf veins',
        'Lower leaves may become affected first',
        'Lesions can enlarge and merge under favorable conditions',
        'Severe infection can cause extensive leaf blighting',
      ],
      treatment: [
        'Use corn hybrids with appropriate disease resistance.',
        'Rotate crops where practical to reduce residue-borne inoculum.',
        'Manage infected crop residue according to local production recommendations.',
        'Scout fields regularly, especially during humid periods.',
        'Use a locally recommended fungicide program when disease risk and crop economics justify it.',
      ],
      isHealthy: false,
    ),

    5: DiseaseInformation(
      classIndex: 5,
      className: 'Corn_(maize)___Common_rust_',
      crop: 'Corn',
      diseaseName: 'Common Rust',
      description:
          'A rust disease producing characteristic cinnamon-brown to dark '
          'brown pustules on corn leaves. Disease development is favored by '
          'cool, wet conditions.',
      symptoms: [
        'Rust-colored or dark brown elongated pustules',
        'Pustules may occur on both leaf surfaces',
        'Powdery rust spores may rub off from pustules',
        'Severe disease can cause chlorosis and leaf death',
      ],
      treatment: [
        'Plant resistant corn hybrids where suitable.',
        'Scout young leaves and monitor disease development during cool, wet weather.',
        'Maintain good crop vigor through appropriate agronomic management.',
        'Where disease pressure warrants it, use a locally registered fungicide according to the label.',
      ],
      isHealthy: false,
    ),

    6: DiseaseInformation(
      classIndex: 6,
      className: 'Corn_(maize)___Northern_Leaf_Blight',
      crop: 'Corn',
      diseaseName: 'Northern Corn Leaf Blight',
      description:
          'A fungal disease producing characteristic long, canoe-shaped '
          'lesions on corn leaves. Prolonged leaf wetness and moderate '
          'temperatures favor development.',
      symptoms: [
        'Long gray-green to tan canoe-shaped lesions',
        'Lesions commonly begin on lower leaves',
        'Dark fungal sporulation may occur in mature lesions',
        'Lesions can spread upward through the canopy',
        'Severe infection can cause extensive leaf blighting',
      ],
      treatment: [
        'Choose hybrids with appropriate resistance.',
        'Rotate crops where practical.',
        'Manage infected corn residue where appropriate.',
        'Scout fields during prolonged wet or humid periods.',
        'Use locally recommended fungicides when disease pressure and crop stage justify treatment.',
      ],
      isHealthy: false,
    ),

    7: DiseaseInformation(
      classIndex: 7,
      className: 'Corn_(maize)___healthy',
      crop: 'Corn',
      diseaseName: 'Healthy Corn',
      description:
          'No disease pattern corresponding to the trained disease classes '
          'was identified for this healthy class.',
      symptoms: [],
      treatment: [
        'Continue regular field scouting.',
        'Maintain appropriate irrigation and nutrition.',
        'Use crop rotation and residue management as part of normal crop planning.',
        'Monitor for disease symptoms during favorable weather conditions.',
      ],
      isHealthy: true,
    ),

    // Grape
    8: DiseaseInformation(
      classIndex: 8,
      className: 'Grape___Black_rot',
      crop: 'Grape',
      diseaseName: 'Grape Black Rot',
      description:
          'A fungal disease affecting grape leaves and fruit. Infected fruit '
          'can turn dark and develop numerous black fruiting bodies before '
          'shriveling into hard black mummies.',
      symptoms: [
        'Reddish-brown circular leaf lesions',
        'Dark fruit lesions covered with small black fruiting bodies',
        'Infected berries shrivel into black mummies',
        'Disease may affect young green grape tissues',
      ],
      treatment: [
        'Remove and destroy mummified berries before the next growing season.',
        'Remove infected fruit clusters and diseased pruning material where practical.',
        'Maintain an open canopy with good airflow and rapid drying.',
        'Use resistant or less susceptible cultivars where available.',
        'Use appropriately timed, locally registered fungicides when disease risk warrants them.',
      ],
      isHealthy: false,
    ),

    9: DiseaseInformation(
      classIndex: 9,
      className: 'Grape___Esca_(Black_Measles)',
      crop: 'Grape',
      diseaseName: 'Esca / Black Measles',
      description:
          'A complex of grapevine trunk-disease fungi. Foliar symptoms can '
          'include interveinal striping, while berries may develop small dark '
          'spots bordered by brown-purple rings.',
      symptoms: [
        'Interveinal red or yellow striping on leaves',
        'Necrotic leaf tissue between veins',
        'Premature drying and leaf drop',
        'Small dark spots with brown-purple borders on berries',
        'Dark staining or concentric discoloration in affected wood',
        'Affected shoots, spurs or canes may eventually die',
      ],
      treatment: [
        'Use healthy planting material from reputable sources.',
        'Protect pruning wounds and avoid unnecessary trunk injuries.',
        'Remove severely diseased wood according to local trunk-disease guidance.',
        'Sanitize pruning equipment and avoid spreading infected material.',
        'Do not rely on fungicides to cure an established permanent wood infection.',
      ],
      isHealthy: false,
    ),

    10: DiseaseInformation(
      classIndex: 10,
      className: 'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
      crop: 'Grape',
      diseaseName: 'Grape Leaf Blight / Isariopsis Leaf Spot',
      description:
          'A fungal leaf disease caused by Pseudocercospora vitis, historically '
          'associated with the name Isariopsis clavispora.',
      symptoms: [
        'Large irregular leaf spots',
        'Spots initially appear dull red to brown',
        'Older lesions become dark or black',
        'Severely affected leaves may become brittle',
        'Defoliation can occur when disease is severe',
      ],
      treatment: [
        'Maintain an open canopy to improve airflow and leaf drying.',
        'Remove heavily infected plant material when practical.',
        'Reduce prolonged leaf wetness.',
        'Monitor poorly ventilated or humid vineyard areas closely.',
        'Use locally registered fungicides according to current grape disease-management guidance when warranted.',
      ],
      isHealthy: false,
    ),

    11: DiseaseInformation(
      classIndex: 11,
      className: 'Grape___healthy',
      crop: 'Grape',
      diseaseName: 'Healthy Grape',
      description:
          'No disease pattern corresponding to the trained disease classes '
          'was identified for this healthy class.',
      symptoms: [],
      treatment: [
        'Maintain good canopy airflow and sunlight penetration.',
        'Monitor vines regularly for leaf, fruit and trunk symptoms.',
        'Use sound pruning and sanitation practices.',
        'Maintain appropriate irrigation and nutrition.',
      ],
      isHealthy: true,
    ),

    // Potato
    12: DiseaseInformation(
      classIndex: 12,
      className: 'Potato___Early_blight',
      crop: 'Potato',
      diseaseName: 'Potato Early Blight',
      description:
          'A fungal disease caused by Alternaria solani. It commonly begins '
          'on older foliage and produces brown target-like lesions.',
      symptoms: [
        'Round brown leaf spots',
        'Concentric target-like rings within larger lesions',
        'Yellowing around severe leaf spots',
        'Dark, slightly sunken stem lesions',
        'Dark sunken lesions on potato tubers',
      ],
      treatment: [
        'Use healthy planting material and resistant or tolerant cultivars where available.',
        'Rotate away from susceptible solanaceous crops where practical.',
        'Maintain adequate plant nutrition and vigor.',
        'Use mulch and avoid soil splashing onto foliage.',
        'Keep foliage dry and improve airflow.',
        'Use locally registered fungicides when disease pressure warrants them.',
      ],
      isHealthy: false,
    ),

    13: DiseaseInformation(
      classIndex: 13,
      className: 'Potato___Late_blight',
      crop: 'Potato',
      diseaseName: 'Potato Late Blight',
      description:
          'A rapidly spreading disease caused by Phytophthora infestans. '
          'Cool, wet conditions strongly favor infection and disease spread.',
      symptoms: [
        'Large irregular olive-brown to dark leaf lesions',
        'Lesions are not restricted by major leaf veins',
        'Leaves and stems can rapidly turn brown and shrivel',
        'White growth may appear under humid conditions',
        'Potato tubers can develop sunken brown to purple lesions',
        'Internal reddish-brown dry rot may occur in tubers',
      ],
      treatment: [
        'Use certified disease-free potato seed.',
        'Control volunteer potatoes and destroy infected cull piles.',
        'Scout frequently during cool, wet weather.',
        'Remove or destroy infected plants promptly where practical.',
        'Use resistant or tolerant varieties where available.',
        'Where chemical control is appropriate, use products specifically registered for late blight and follow the local label.',
      ],
      isHealthy: false,
    ),

    14: DiseaseInformation(
      classIndex: 14,
      className: 'Potato___healthy',
      crop: 'Potato',
      diseaseName: 'Healthy Potato',
      description:
          'No disease pattern corresponding to the trained disease classes '
          'was identified for this healthy class.',
      symptoms: [],
      treatment: [
        'Use certified healthy planting material.',
        'Rotate potatoes and other solanaceous crops.',
        'Maintain appropriate irrigation and nutrition.',
        'Scout foliage regularly for early disease symptoms.',
      ],
      isHealthy: true,
    ),

    // Tomato
    15: DiseaseInformation(
      classIndex: 15,
      className: 'Tomato___Bacterial_spot',
      crop: 'Tomato',
      diseaseName: 'Bacterial Spot',
      description:
          'A bacterial disease that affects tomato leaves, stems and fruit. '
          'Warm, humid and wet conditions favor disease development and spread.',
      symptoms: [
        'Small brown circular leaf spots',
        'Yellow halos around leaf spots',
        'Leaf centers may fall out and form small holes',
        'Dark spots can develop on stems and fruit',
        'Fruit lesions can reduce marketability',
      ],
      treatment: [
        'Start with disease-free seed and transplants.',
        'Avoid overhead irrigation and keep foliage dry.',
        'Avoid working among plants when foliage is wet.',
        'Disinfect pruning tools and equipment.',
        'Remove or bury infected crop debris after harvest.',
        'Rotate away from tomato and related crops where practical.',
        'Use only locally registered products when chemical management is warranted.',
      ],
      isHealthy: false,
    ),

    16: DiseaseInformation(
      classIndex: 16,
      className: 'Tomato___Early_blight',
      crop: 'Tomato',
      diseaseName: 'Tomato Early Blight',
      description:
          'A common fungal disease that usually starts on older leaves and '
          'produces dark spots with characteristic concentric rings.',
      symptoms: [
        'Small dark spots on older lower leaves',
        'Brown circular lesions with concentric rings',
        'Yellow tissue surrounding larger lesions',
        'Leaf death and defoliation',
        'Dark stem lesions',
        'Dark lesions can occur on fruit near the stem',
      ],
      treatment: [
        'Use resistant or tolerant cultivars where available.',
        'Rotate away from tomatoes and related crops.',
        'Use pathogen-free seed or healthy transplants.',
        'Water at the plant base and keep foliage dry.',
        'Use mulch to reduce soil splash onto leaves.',
        'Remove infected leaves carefully and sanitize tools.',
        'Use locally registered fungicides when disease pressure warrants them.',
      ],
      isHealthy: false,
    ),

    17: DiseaseInformation(
      classIndex: 17,
      className: 'Tomato___Late_blight',
      crop: 'Tomato',
      diseaseName: 'Tomato Late Blight',
      description:
          'A rapidly spreading disease caused by Phytophthora infestans. '
          'Cool, wet conditions favor rapid development.',
      symptoms: [
        'Large irregular dark brown or olive lesions',
        'Green-gray margins may surround lesions',
        'Leaves and stems can rapidly turn brown',
        'White growth may occur under humid conditions',
        'Firm dark lesions can develop on fruit',
        'Disease can spread rapidly through a crop',
      ],
      treatment: [
        'Scout frequently, particularly during cool, wet weather.',
        'Keep foliage dry and improve plant spacing and airflow.',
        'Remove infected plant material promptly where practical.',
        'Use healthy transplants and certified planting material.',
        'Avoid allowing infected crop residue or volunteer plants to persist.',
        'Where chemical management is warranted, use products specifically registered for late blight and follow the local label.',
      ],
      isHealthy: false,
    ),

    18: DiseaseInformation(
      classIndex: 18,
      className: 'Tomato___Leaf_Mold',
      crop: 'Tomato',
      diseaseName: 'Tomato Leaf Mold',
      description:
          'A fungal disease caused by Passalora fulva. It is especially '
          'associated with greenhouse and high-tunnel production under high '
          'relative humidity.',
      symptoms: [
        'Pale yellow-green spots on the upper leaf surface',
        'Olive-green to brown velvety growth underneath leaves',
        'Older leaves are usually affected first',
        'Leaves become brown, wither and die',
        'Severe infections can affect blossoms and fruit',
      ],
      treatment: [
        'Reduce greenhouse or high-tunnel humidity.',
        'Increase ventilation and air circulation.',
        'Avoid prolonged leaf wetness and overhead irrigation.',
        'Remove infected leaves and plant debris carefully.',
        'Use resistant cultivars where available.',
        'Use locally registered fungicides when appropriate for the production system.',
      ],
      isHealthy: false,
    ),

    19: DiseaseInformation(
      classIndex: 19,
      className: 'Tomato___Septoria_leaf_spot',
      crop: 'Tomato',
      diseaseName: 'Septoria Leaf Spot',
      description:
          'A fungal leaf disease caused by Septoria lycopersici. It commonly '
          'begins on lower foliage and produces numerous small spots.',
      symptoms: [
        'Small circular leaf spots',
        'Dark margins with tan or gray centers',
        'Small black fruiting bodies may appear inside mature spots',
        'Lower leaves are often affected first',
        'Severe infection can cause progressive defoliation',
      ],
      treatment: [
        'Remove infected leaves when disease is detected early.',
        'Keep foliage dry and water at the plant base.',
        'Improve airflow with appropriate spacing and staking.',
        'Use mulch to reduce soil splash.',
        'Remove infected crop debris at the end of the season.',
        'Do not save seed from infected plants.',
        'Use locally registered fungicides when disease pressure warrants them.',
      ],
      isHealthy: false,
    ),

    20: DiseaseInformation(
      classIndex: 20,
      className: 'Tomato___Spider_mites Two-spotted_spider_mite',
      crop: 'Tomato',
      diseaseName: 'Two-Spotted Spider Mite',
      description:
          'A mite pest rather than a fungal or bacterial disease. Heavy feeding '
          'can cause stippling, plant stress, webbing and severe loss of plant vigor.',
      symptoms: [
        'Fine yellow or pale stippling on leaves',
        'Tiny mites, often visible on leaf undersides',
        'Bronzing or yellowing of foliage',
        'Fine webbing during heavier infestations',
        'Severe infestations can stunt or kill plants',
      ],
      treatment: [
        'Reduce plant stress with appropriate irrigation and mulching.',
        'Inspect leaf undersides regularly, especially during hot or dry weather.',
        'Use water sprays to dislodge mites where appropriate.',
        'Conserve predatory mites and other natural enemies.',
        'Avoid unnecessary broad-spectrum insecticides that can destroy natural enemies.',
        'If treatment is necessary, use a locally registered miticide, insecticidal soap or horticultural oil according to its label.',
      ],
      isHealthy: false,
    ),

    21: DiseaseInformation(
      classIndex: 21,
      className: 'Tomato___Target_Spot',
      crop: 'Tomato',
      diseaseName: 'Tomato Target Spot',
      description:
          'A fungal disease caused by Corynespora cassiicola. It can affect '
          'leaves, stems and fruit and is favored by warm temperatures and '
          'high moisture.',
      symptoms: [
        'Small dark leaf lesions that enlarge over time',
        'Yellow halos around expanding lesions',
        'Concentric rings may develop in mature lesions',
        'Lesions can merge and cause leaf tissue collapse',
        'Dark stem and petiole lesions',
        'Brown sunken fruit lesions that may crack',
      ],
      treatment: [
        'Improve canopy airflow and reduce prolonged leaf wetness.',
        'Avoid dense, poorly ventilated plant growth.',
        'Remove infected plant material where practical.',
        'Manage crop residue and volunteer plants.',
        'Scout the inner canopy where humidity may remain high.',
        'Use a locally registered fungicide program when disease pressure warrants it.',
      ],
      isHealthy: false,
    ),

    22: DiseaseInformation(
      classIndex: 22,
      className: 'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
      crop: 'Tomato',
      diseaseName: 'Tomato Yellow Leaf Curl Virus',
      description:
          'A viral disease primarily spread by whiteflies. Infected plants '
          'can develop leaf curling, yellowing, stunting and reduced fruit set.',
      symptoms: [
        'Upward or downward curling of leaves',
        'Yellowing along leaf margins and veins',
        'Small or distorted new leaves',
        'Stunted plant growth',
        'Flower drop and reduced fruit production',
      ],
      treatment: [
        'Use TYLCV-resistant or tolerant cultivars where available.',
        'Use virus-free and whitefly-free transplants.',
        'Monitor and manage whitefly populations.',
        'Remove and destroy infected plants where practical.',
        'Control weeds that may serve as virus reservoirs.',
        'Remove old tomato crops promptly after harvest.',
        'There is no treatment that cures an already infected plant.',
      ],
      isHealthy: false,
    ),

    23: DiseaseInformation(
      classIndex: 23,
      className: 'Tomato___Tomato_mosaic_virus',
      crop: 'Tomato',
      diseaseName: 'Tomato Mosaic Virus',
      description:
          'A viral disease that can cause mottled foliage, leaf distortion, '
          'stunting and abnormal fruit development. Virus symptoms can overlap '
          'with other tomato disorders.',
      symptoms: [
        'Light and dark green mosaic patterns on leaves',
        'Leaf distortion or curling',
        'Reduced leaf size in some infections',
        'Plant stunting',
        'Uneven fruit ripening or abnormal fruit coloration',
      ],
      treatment: [
        'Use resistant varieties when available.',
        'Use clean seed and healthy transplants.',
        'Wash hands before and after handling plants.',
        'Disinfect tools and equipment between plants or production areas.',
        'Remove and destroy suspected infected plants.',
        'Control weeds and volunteer plants that may contribute to virus persistence.',
        'There is no chemical cure for an infected plant.',
      ],
      isHealthy: false,
    ),

    24: DiseaseInformation(
      classIndex: 24,
      className: 'Tomato___healthy',
      crop: 'Tomato',
      diseaseName: 'Healthy Tomato',
      description:
          'No disease pattern corresponding to the trained disease classes '
          'was identified for this healthy class.',
      symptoms: [],
      treatment: [
        'Continue regular scouting of leaves, stems and fruit.',
        'Maintain good plant spacing and airflow.',
        'Water at the plant base when practical.',
        'Maintain appropriate nutrition and irrigation.',
        'Remove diseased crop debris promptly when detected.',
      ],
      isHealthy: true,
    ),
  };

  static List<DiseaseInformation> get all {
    final items = _diseases.values.toList();

    items.sort((a, b) {
      final cropCompare = a.crop.compareTo(b.crop);

      if (cropCompare != 0) {
        return cropCompare;
      }

      return a.diseaseName.compareTo(b.diseaseName);
    });

    return List.unmodifiable(items);
  }

  static DiseaseInformation getByClassIndex(int classIndex) {
    final disease = _diseases[classIndex];

    if (disease == null) {
      throw StateError(
        'No disease information exists for class index $classIndex.',
      );
    }

    return disease;
  }
}
