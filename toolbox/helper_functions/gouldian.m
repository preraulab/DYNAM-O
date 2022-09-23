function map = gouldian(N)

% These colour maps are released under the Creative Commons BY License.
% A summary of the conditions can be found at
% https://creativecommons.org/licenses/by/4.0/
% Basically, you are free to use these colour maps in anyway you wish
% as long as you give appropriate credit.
%
% Reference:
% Peter Kovesi. Good Colour Maps: How to Design Them.
% arXiv:1509.03700 [cs.GR] 2015
% https://arxiv.org/abs/1509.03700

% Copyright (c) 2014-2020 Peter Kovesi
% Centre for Exploration Targeting
% The University of Western Australia
% peter.kovesi at uwa edu au

map = [0.189342 0.189388 0.189376
       0.193131 0.190712 0.199397
       0.196840 0.192036 0.209483
       0.200353 0.193384 0.219503
       0.203846 0.194729 0.229514
       0.207167 0.196064 0.239514
       0.210383 0.197404 0.249498
       0.213485 0.198744 0.259473
       0.216519 0.200097 0.269433
       0.219401 0.201475 0.279356
       0.222188 0.202867 0.289276
       0.224860 0.204288 0.299165
       0.227479 0.205674 0.309056
       0.229939 0.207101 0.318890
       0.232356 0.208515 0.328735
       0.234657 0.209960 0.338526
       0.236854 0.211429 0.348322
       0.238926 0.212886 0.358069
       0.240930 0.214388 0.367794
       0.242833 0.215915 0.377480
       0.244649 0.217429 0.387148
       0.246377 0.218982 0.396755
       0.248039 0.220561 0.406374
       0.249550 0.222130 0.415896
       0.251027 0.223738 0.425433
       0.252382 0.225383 0.434872
       0.253662 0.227046 0.444308
       0.254859 0.228744 0.453649
       0.255938 0.230428 0.462969
       0.256967 0.232188 0.472241
       0.257884 0.233938 0.481443
       0.258749 0.235750 0.490608
       0.259518 0.237584 0.499673
       0.260194 0.239417 0.508735
       0.260789 0.241310 0.517673
       0.261312 0.243207 0.526584
       0.261749 0.245162 0.535378
       0.262110 0.247163 0.544130
       0.262393 0.249183 0.552801
       0.262596 0.251255 0.561378
       0.262728 0.253334 0.569905
       0.262777 0.255474 0.578299
       0.262755 0.257633 0.586633
       0.262657 0.259856 0.594867
       0.262485 0.262105 0.602993
       0.262245 0.264391 0.611058
       0.261930 0.266729 0.618971
       0.261547 0.269127 0.626782
       0.261097 0.271522 0.634511
       0.260577 0.274011 0.642084
       0.259996 0.276530 0.649568
       0.259355 0.279093 0.656917
       0.258628 0.281700 0.664118
       0.257840 0.284348 0.671215
       0.257016 0.287056 0.678158
       0.256102 0.289832 0.684941
       0.255169 0.292640 0.691605
       0.254148 0.295507 0.698097
       0.253075 0.298435 0.704417
       0.251954 0.301408 0.710593
       0.250765 0.304447 0.716601
       0.249528 0.307539 0.722389
       0.248275 0.310716 0.728012
       0.246925 0.313913 0.733472
       0.245539 0.317186 0.738697
       0.244115 0.320540 0.743699
       0.242654 0.323924 0.748504
       0.241150 0.327381 0.753103
       0.239600 0.330913 0.757443
       0.238006 0.334541 0.761516
       0.236379 0.338195 0.765356
       0.234707 0.341944 0.768936
       0.232957 0.345742 0.772259
       0.231219 0.349644 0.775253
       0.229399 0.353609 0.777935
       0.227571 0.357673 0.780305
       0.225682 0.361791 0.782357
       0.223731 0.365996 0.784071
       0.221736 0.370273 0.785418
       0.219701 0.374658 0.786389
       0.217586 0.379123 0.786932
       0.215395 0.383694 0.787032
       0.213121 0.388352 0.786686
       0.210777 0.393108 0.785864
       0.208309 0.397977 0.784543
       0.205718 0.402939 0.782682
       0.202959 0.408015 0.780258
       0.200013 0.413212 0.777237
       0.196907 0.418511 0.773557
       0.193492 0.423951 0.769179
       0.189761 0.429532 0.764024
       0.185683 0.435254 0.758053
       0.181063 0.441099 0.751219
       0.175896 0.447116 0.743445
       0.170323 0.453215 0.734936
       0.164773 0.459245 0.726183
       0.159557 0.465123 0.717469
       0.154697 0.470884 0.708801
       0.150229 0.476510 0.700177
       0.146206 0.482016 0.691612
       0.142699 0.487403 0.683097
       0.139616 0.492668 0.674628
       0.137134 0.497857 0.666204
       0.135224 0.502910 0.657839
       0.133952 0.507892 0.649514
       0.133244 0.512764 0.641224
       0.133155 0.517562 0.632993
       0.133755 0.522252 0.624801
       0.135034 0.526879 0.616658
       0.136868 0.531410 0.608556
       0.139292 0.535866 0.600482
       0.142410 0.540250 0.592469
       0.146095 0.544555 0.584481
       0.150274 0.548796 0.576544
       0.154913 0.552951 0.568626
       0.160055 0.557054 0.560759
       0.165694 0.561067 0.552927
       0.171709 0.565022 0.545133
       0.178095 0.568920 0.537372
       0.184809 0.572755 0.529639
       0.191875 0.576519 0.521931
       0.199206 0.580214 0.514275
       0.206841 0.583847 0.506625
       0.214699 0.587418 0.499016
       0.222863 0.590929 0.491445
       0.231201 0.594379 0.483870
       0.239724 0.597768 0.476339
       0.248498 0.601091 0.468830
       0.257449 0.604358 0.461339
       0.266573 0.607559 0.453865
       0.275868 0.610694 0.446410
       0.285307 0.613760 0.438969
       0.294961 0.616776 0.431564
       0.304752 0.619723 0.424144
       0.314663 0.622599 0.416751
       0.324755 0.625413 0.409360
       0.335034 0.628162 0.401970
       0.345398 0.630843 0.394601
       0.355914 0.633453 0.387220
       0.366582 0.635993 0.379853
       0.377404 0.638457 0.372475
       0.388352 0.640850 0.365097
       0.399417 0.643175 0.357720
       0.410669 0.645419 0.350316
       0.422032 0.647587 0.342909
       0.433438 0.649698 0.335490
       0.444722 0.651773 0.328064
       0.455785 0.653828 0.320686
       0.466672 0.655874 0.313308
       0.477382 0.657901 0.305960
       0.487953 0.659906 0.298597
       0.498383 0.661900 0.291283
       0.508689 0.663870 0.283954
       0.518887 0.665818 0.276660
       0.528993 0.667752 0.269372
       0.539008 0.669659 0.262074
       0.548957 0.671540 0.254810
       0.558830 0.673405 0.247532
       0.568658 0.675241 0.240243
       0.578438 0.677058 0.232983
       0.588177 0.678836 0.225754
       0.597890 0.680590 0.218492
       0.607584 0.682321 0.211245
       0.617246 0.684017 0.204011
       0.626900 0.685691 0.196771
       0.636559 0.687322 0.189521
       0.646204 0.688926 0.182278
       0.655869 0.690481 0.175096
       0.665536 0.692015 0.167883
       0.675223 0.693498 0.160712
       0.684934 0.694943 0.153560
       0.694669 0.696353 0.146462
       0.704443 0.697709 0.139394
       0.714252 0.699023 0.132464
       0.724106 0.700294 0.125583
       0.734008 0.701507 0.118832
       0.743959 0.702676 0.112218
       0.753969 0.703784 0.105797
       0.764041 0.704835 0.099637
       0.774177 0.705828 0.093802
       0.784396 0.706760 0.088385
       0.794684 0.707615 0.083462
       0.805054 0.708412 0.079113
       0.815514 0.709134 0.075535
       0.826064 0.709774 0.072860
       0.836705 0.710332 0.071189
       0.847452 0.710808 0.070548
       0.858243 0.711234 0.071057
       0.868611 0.711773 0.072050
       0.878114 0.712605 0.073094
       0.886818 0.713741 0.073971
       0.894854 0.715124 0.074707
       0.902285 0.716740 0.075383
       0.909182 0.718556 0.075978
       0.915614 0.720562 0.076505
       0.921617 0.722744 0.076968
       0.927220 0.725096 0.077371
       0.932490 0.727575 0.077720
       0.937428 0.730205 0.078016
       0.942050 0.732962 0.078259
       0.946396 0.735830 0.078457
       0.950495 0.738819 0.078611
       0.954350 0.741901 0.078722
       0.957981 0.745085 0.078793
       0.961392 0.748364 0.078824
       0.964597 0.751732 0.078816
       0.967614 0.755181 0.078772
       0.970441 0.758706 0.078692
       0.973103 0.762303 0.078579
       0.975594 0.765977 0.078434
       0.977934 0.769709 0.078256
       0.980126 0.773506 0.078048
       0.982167 0.777374 0.077809
       0.984062 0.781290 0.077541
       0.985825 0.785263 0.077244
       0.987460 0.789288 0.076919
       0.988970 0.793362 0.076568
       0.990361 0.797476 0.076191
       0.991637 0.801639 0.075789
       0.992806 0.805845 0.075362
       0.993863 0.810089 0.074907
       0.994799 0.814378 0.074429
       0.995630 0.818703 0.073943
       0.996364 0.823068 0.073414
       0.997004 0.827462 0.072791
       0.997552 0.831891 0.072165
       0.997998 0.836346 0.071588
       0.998344 0.840839 0.070913
       0.998603 0.845356 0.070203
       0.998779 0.849902 0.069562
       0.998870 0.854470 0.068822
       0.998859 0.859070 0.068012
       0.998767 0.863698 0.067200
       0.998599 0.868343 0.066361
       0.998349 0.873004 0.065502
       0.998004 0.877697 0.064618
       0.997586 0.882405 0.063710
       0.997099 0.887134 0.062807
       0.996521 0.891886 0.061722
       0.995865 0.896656 0.060732
       0.995144 0.901437 0.059763
       0.994344 0.906240 0.058599
       0.993462 0.911060 0.057436
       0.992511 0.915888 0.056362
       0.991487 0.920735 0.055104
       0.990378 0.925605 0.053841
       0.989209 0.930483 0.052556
       0.987965 0.935370 0.051252
       0.986641 0.940279 0.049917
       0.985254 0.945193 0.048509
       0.983791 0.950117 0.047046
       0.982253 0.955060 0.045473
       0.980653 0.960011 0.043886
       0.978970 0.964969 0.042319
       0.977223 0.969939 0.040620
       0.975415 0.974915 0.038860];

if nargin>0 && ~isempty(N) && N < size(map,1)
        tmap = map;
        tN = size(tmap,1);
        map = zeros(N,3);
        for j = 1:3
            map(:,j) = interp1(0:(tN-1), tmap(:,j), (0:(N-1))*(tN-1)/(N-1));
        end
end
